
import Foundation
import PerfectLib
import INIParser

public extension String {

  public var sysEnv: String {
    guard let e = getenv(self) else { return "" }
    return String(cString: e)
  }
}

public class Aliyun {

  public enum Exception:Error {
    case InvalidConfigHome
    case InvalidRegion
    case InvalidOutputFormat
    case InvalidAccessKey
    case InvalidAccessSecret
    case InvalidSystemProcess
    case InvalidLogin
  }
  public var accessKeyId = ""
  public var accessKeySecret = ""
  public var region = ""
  public static let ConfigPath = "HOME".sysEnv + "/.aliyuncli"
  public static let dockerImage = "rockywei/aliyun:v1"
  public static let ConfigMapping = "HOME".sysEnv + ":/root"
  public static let Bash = "/bin/bash"

  public var regions: [String:String] = [:]
  public var instanceTypes: [InstanceType] = []

  public struct InstanceType {
    public let InstanceTypeId: String
    public let CpuCoreCount: Int
    public let MemorySize: Int
    public let InstanceTypeFamily: String
    public init(_ dic: [String: Any] = [:]) {
      InstanceTypeId = dic["InstanceTypeId"] as? String ?? ""
      CpuCoreCount = dic["CpuCoreCount"] as? Int ?? 0
      MemorySize = Int(dic["MemorySize"] as? Double ?? 0.0)
      InstanceTypeFamily = dic["InstanceTypeFamily"] as? String ?? ""
    }
  }

  public func loadInstanceTypes(completion: @escaping (Bool, String) -> Void) throws {
    let params = ["run", "-v", Aliyun.ConfigMapping, "-e", "HOME=/root", Aliyun.dockerImage, "aliyuncli", "ecs", "DescribeImageSupportInstanceTypes", "--secure", "--ImageId", "ubuntu_16_0402_64_40G_base_20170222.vhd"]

    try runProc("docker", args: params) { ret in
      guard let a = try? ret.jsonDecode() as? [String: Any],
        let b = a?["InstanceTypes"] as? [String: Any],
        let json = b["InstanceType"] as? [[String: Any]],
        json.count > 0 else {
          completion(false, "Loading InstanceTypes Failure")
          return
      }
      self.instanceTypes = json.map { InstanceType($0) }
      completion(self.instanceTypes.count > 0, "InstanceTypes Loaded")
    }
  }

  public func loadConfig() throws {
    let config = File(Aliyun.ConfigPath)
    guard config.isDir else { throw Exception.InvalidConfigHome }

    let ini1 = try INIParser(Aliyun.ConfigPath + "/configure")
    region = ini1.sections["[default]"]?["region"] ?? ""
    guard !region.isEmpty else { throw Exception.InvalidRegion }

    let json = ini1.sections["[default]"]?["output"] ?? "text"
    guard json == "json" else { throw Exception.InvalidOutputFormat }

    let ini2 = try INIParser(Aliyun.ConfigPath + "/credentials")
    accessKeyId = ini2.sections["[default]"]?["aliyun_access_key_id"] ?? ""
    accessKeySecret = ini2.sections["[default]"]?["aliyun_access_key_secret"] ?? ""

    guard !accessKeyId.isEmpty else { throw Exception.InvalidAccessKey }
    guard !accessKeySecret.isEmpty else { throw Exception.InvalidAccessSecret }
  }

  public func loadRegions(completion: @escaping (Bool, String) -> Void) throws {
    let params = ["run", "-v", Aliyun.ConfigMapping, "-e", "PWD=/root", "-e", "HOME=/root", Aliyun.dockerImage, "aliyuncli", "ecs", "DescribeRegions", "--secure"]

    try runProc("docker", args: params) { ret in
      guard let a = try? ret.jsonDecode() as? [String: Any],
        let b = a?["Regions"] as? [String: Any],
        let json = b["Region"] as? [[String: String]],
        json.count > 0 else {
          completion(false, "Loading Region JSON Failure")
          return
      }
      self.regions.removeAll()
      json.forEach { i in
        if let name = i["LocalName"], let id = i["RegionId"] {
          self.regions[id] = name
        }
      }
      completion(self.regions.count > 0, "Regions Loaded")
    }
  }

  public init() throws {
    try loadConfig()
  }

  public func createKeyPair(keyName: String, pathToSave: String, completion: @escaping (Bool, String) -> Void) throws {
    let path = "\(pathToSave)/\(keyName).pem"
    let f = File(path)
    if f.exists {
      completion(true, path)
      return
    }//end if
    let params = ["run", "-v", Aliyun.ConfigMapping, "-e", "HOME=/root", Aliyun.dockerImage, "aliyuncli", "ecs", "CreateKeyPair", "--secure", "--KeyPairName", keyName ]
    try runProc("docker", args: params) { ret in
      do {
        guard let k = try ret.jsonDecode() as? [String: String],
        let body = k["PrivateKeyBody"],
          // let fprint = k["KeyPairFingerPrint"],
        let name = k["KeyPairName"],
        name == keyName
        else {
          completion(false, ret)
          return
        }
        try f.open(.write)
        try f.write(string: body)
        f.close()
        chmod(path, 256)
        completion(true, path)
      }catch {
        completion(false, ret)
      }
    }
  }

  public func deleteKeyPair(keyName: String, completion: @escaping (Bool, String) -> Void) throws {
    let name = "[\"\(keyName)\"]"
    print(name)
    let params = ["run", "-v", Aliyun.ConfigMapping, "-e", "HOME=/root", Aliyun.dockerImage, "aliyuncli", "ecs", "DeleteKeyPairs", "--secure", " --KeyPairNames", name ]
    try runProc("docker", args: params) { ret in
      completion(!ret.contains("Error"), ret)
    }
  }
  public static func DockerLogin(userName: String, password: String, completion: @escaping (Bool, String) -> Void) {
    let params = ["login", "-u", userName, "-p", password]

    do {
      try runProc("docker", args: params) { ret in
        completion( ret == "Login Succeeded\n", ret)
      }
    }catch {
      completion(false, "Docker Login Succeed")
    }
  }

  public static func InstallDockerImage(completion: @escaping (Bool, String) -> Void ) {
    let params = ["pull", dockerImage]

    do {
      try runProc("docker", args: params) { ret in
        completion( !ret.contains("Error"), ret )
      }
    }catch {
      completion(false, "Docker Image Installation Succeed")
    }

  }
  
  public static func Configure(keyId: String, secret: String, region: String, completion: @escaping (Bool, String) -> Void)  {

    let params = ["run", "-v", ConfigMapping, dockerImage, Bash, "aliconfig", keyId, secret, region]
    print("docker", params.joined(separator: " "))
    do {
      try runProc("docker", args: params) { ret in
        completion( !ret.contains("Error"), ret )
      }
    }catch {
      completion(false, "Aliyun Configuration Succeed")
    }
  }
}
