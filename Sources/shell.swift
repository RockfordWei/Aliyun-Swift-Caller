//
//  shell.swift
//  Aliyun
//
//  Created by Rocky Wei on 2017-07-24.
//
//

import Foundation
import PerfectLib

extension File {
  func switchToNonBlocking() {
    guard self.isOpen else {
      return
    }
    let fd = Int32(self.fd)
    let flags = fcntl(fd, F_GETFL)
    guard flags >= 0 else {
      return
    }
    let _ = fcntl(fd, F_SETFL, flags | O_NONBLOCK)
    var one = Int32(1)
    setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &one, UInt32(MemoryLayout<Int32>.size))
    setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &one, UInt32(MemoryLayout<Int32>.size));
  }
}

func runProc(_ cmd: String, args: [String], envs: [String:String] = [:], quoteArgs: Bool = true, stderr: Bool = false, cd: String? = nil, read: ((String) -> ())? = nil) throws {
  var ienvs = ["PATH", "HOME", "LANG"].map { ($0, $0.sysEnv) }

  for e in envs {
    ienvs.append(e)
  }
  let cmdPath = File(cmd).path
  var newCmd: String
  if let cd = cd {
    newCmd = "cd '\(cd)' && '\(cmdPath)\'"
  } else {
    newCmd = "'\(cmdPath)\'"
  }

  for n in 1...args.count {
    if quoteArgs {
      newCmd.append(" \"${\(n)}\"")
    } else {
      newCmd.append(" ${\(n)}")
    }
  }
  let shell = "/bin/sh"
  let proc = try SysProcess(shell, args: ["--login", "-ci", newCmd, cmdPath] + args, env: ienvs)
  let out: File? = stderr ? proc.stderr : proc.stdout
  var accumulator = [UInt8]()
  if let read = read {
    while true {
      do {
        guard let s = try out?.readSomeBytes(count: 1024) , s.count > 0 else {
          break
        }
        accumulator.append(contentsOf: s)
      } catch PerfectLib.PerfectError.fileError(let code, _) {
        if code != EINTR {
          break
        }
      }
    }
    if accumulator.count > 0 {
      accumulator.append(0)
      read(String(cString: accumulator))
    }
  }
  let res = try proc.wait(hang: true)
  if res != 0 {
    let s = try proc.stderr?.readString()
    throw PerfectError.systemError(Int32(res), s!.replacingOccurrences(of: "sh: no job control in this shell\n", with: ""))
  }
}

func runProc(_ cmd: String, args: [String], envs: [String:String], quoteArgs: Bool, cd: String? = nil, readStdin: ((String) -> ()), readStderr: ((String) -> ())) throws -> Int {
  var ienvs = ["PATH", "HOME", "LANG"].map { ($0, $0.sysEnv) }
  for e in envs {
    ienvs.append(e)
  }
  let cmdPath = File(cmd).path
  var newCmd: String
  if let cd = cd {
    newCmd = "cd '\(cd)' && '\(cmdPath)\'"
  } else {
    newCmd = "'\(cmdPath)\'"
  }
  for n in 1...args.count {
    if quoteArgs {
      newCmd.append(" \"${\(n)}\"")
    } else {
      newCmd.append(" ${\(n)}")
    }
  }
  let shell = "/bin/sh"
  let proc = try SysProcess(shell, args: ["--login", "-ci", newCmd, cmdPath] + args, env: ienvs)

  proc.stdout?.switchToNonBlocking()
  proc.stderr?.switchToNonBlocking()

  var res = -1 as Int32
  while proc.isOpen() {
    do {
      res = try proc.wait(hang: false)

      var writeStr = ""
      do {
        while let s = try proc.stdout?.readSomeBytes(count: 2048), s.count > 0 {
          let str = UTF8Encoding.encode(bytes: s)
          writeStr.append(str)
        }
      } catch PerfectLib.PerfectError.fileError(let code, _) where code == EAGAIN {}
      if !writeStr.isEmpty {
        readStdin(writeStr.replacingOccurrences(of: "sh: no job control in this shell\n", with: ""))
      }

      writeStr = ""
      do {
        while let s = try proc.stderr?.readSomeBytes(count: 2048), s.count > 0 {
          let str = UTF8Encoding.encode(bytes: s)
          writeStr.append(str)
        }
      } catch PerfectLib.PerfectError.fileError(let code, _) where code == EAGAIN {}
      if !writeStr.isEmpty {
        readStderr(writeStr.replacingOccurrences(of: "sh: no job control in this shell\n", with: ""))
      }
      
      usleep(25000)
    } catch PerfectLib.PerfectError.fileError(let code, _) {
      if code != EINTR {
        break
      }
    }
  }
  
  return Int(res)
}
