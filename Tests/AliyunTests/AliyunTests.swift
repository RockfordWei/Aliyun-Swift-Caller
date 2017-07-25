import XCTest
@testable import Aliyun
import PerfectLib
import Foundation

func SyncExec(_ timeout: Int = 5, command: @escaping (UnsafeMutablePointer<Bool>) -> Void ) {
  var pending = true
  command(&pending)
  let now = time(nil)
  var then = now
  var shouldWait = true
  repeat {
    then = time(nil)
    usleep(10000)
    shouldWait = (then - now) < timeout
  } while pending && shouldWait
  //XCTAssertTrue(shouldWait)
}

class AliyunTests: XCTestCase {

  let testKeyName = "alikeytest"
  func testAliyun() {
    let hidden = File(Aliyun.ConfigPath)
    if hidden.exists {

      SyncExec { pLock in
        do {
          try runProc("rm", args: ["-rf", Aliyun.ConfigPath]) { succes in
            pLock.pointee = false
          }
        }catch{
          XCTFail("rmdir (\(Aliyun.ConfigPath)) failed - \(error)")
          pLock.pointee = false
        }
      }
    }

    SyncExec { pLock in
      Aliyun.DockerLogin(userName: "DCKUSR".sysEnv, password: "DCKPWD".sysEnv) {
        success, message in
        XCTAssertTrue(success)
        print(message)
        pLock.pointee = false
      }
    }

    SyncExec { pLock in
      Aliyun.InstallDockerImage { success, message in
        XCTAssertTrue(success)
        print(message)
        pLock.pointee = false
      }
    }

    SyncExec { pLock in
      Aliyun.Configure(keyId: "ACSKEY".sysEnv, secret: "ACSSEC".sysEnv, region: "DEFREG".sysEnv) {
        success, message in
        XCTAssertTrue(success)
        print(message)
        pLock.pointee = false
      }
    }
    SyncExec { pLock in
      if let a = try? Aliyun() {
        do {
          try a.loadRegions { success, message in
            XCTAssertTrue(success)
            pLock.pointee = false
            XCTAssertFalse(a.regions.isEmpty)
            print(a.regions)
          }
        }catch {
          XCTFail("\(error.localizedDescription)")
        }
      }
    }
    do {
      let a = try Aliyun()
      XCTAssertFalse(a.region.isEmpty)
      XCTAssertFalse(a.accessKeyId.isEmpty)
      XCTAssertFalse(a.accessKeySecret.isEmpty)
    } catch {
      XCTFail("\(error)")
    }

    SyncExec { pLock in
      if let a = try? Aliyun() {
        do {
          try a.loadInstanceTypes { success, message in
            XCTAssertTrue(success)
            pLock.pointee = false
            print(a.instanceTypes)
            XCTAssertFalse(a.instanceTypes.isEmpty)
          }
        }catch {
          XCTFail("\(error.localizedDescription)")
        }
      }
    }

    SyncExec { pLock in
      if let a = try? Aliyun() {
        do {

          try a.createKeyPair(keyName: self.testKeyName, pathToSave: "HOME".sysEnv + "/.ssh") { success, path in
            XCTAssertTrue(success)
            pLock.pointee = false
            let f = File(path)
            XCTAssertTrue(f.exists)
            do {
              try f.open(.read)
              let key = try f.readString()
              f.close()
              XCTAssertTrue(key.contains("BEGIN RSA PRIVATE KEY"))
              XCTAssertTrue(key.contains("END RSA PRIVATE KEY"))
            }catch {
              XCTFail("\(error.localizedDescription)")
            }
          }
        }catch {
          XCTFail("\(error.localizedDescription)")
        }
      }
    }
  }


  static var allTests = [
    ("testAliyun", testAliyun)
    ]
}
