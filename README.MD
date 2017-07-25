# Aliyun CLI Swift Caller

Only works with MacOS X / Docker
 
# Install Aliyun CLI

```
curl "https://bootstrap.pypa.io/get-pip.py" -o "pip-install.py"
sudo python pip-install.py
sudo pip install -U pip
sudo pip install aliyuncli
sudo pip install aliyun-python-sdk-ecs
complete -C '/usr/local/bin/aliyun_completer' aliyuncli
```
# Get Help

Command line `aliyuncli ecs help` can show all commands.

Command line `aliyuncli ecs <Command> help` can show the usage of the specific command.

**HINTS** `aliyuncli` supports auto-complete, as the last line of installation.

# Access Key

Register & Log on to the console of Alibaba Cloud at [https://intl.aliyun.com/](https://intl.aliyun.com/).

Click Home -> (Monitor & Management) Resource Access Management until you see a RAM dashboard:

<p><img src='https://github.com/RockfordWei/Aliyun-CLI-Deployment-Guide/blob/master/ram.png?raw=true'></img></p>

Create a new group and authorize its police to ECS full access, then click the user that just created.

<p><img src='https://github.com/RockfordWei/Aliyun-CLI-Deployment-Guide/blob/master/user.png?raw=true'></img></p>

Click "Create AccessKey", then save it.

Once created, use this access key to configure the cli.
**NOTE** 
Region list & IDs can be found at [https://intl.aliyun.com/help/doc-detail/40654.htm](https://intl.aliyun.com/help/doc-detail/40654.htm)

Also, output format can be JSON / table, etc.

```
$ aliyuncli configure
Aliyun Access Key ID [None]: <TYPE YOUR ACCESS KEY ID HERE>
Aliyun Access Key Secret [None]: <TYPE YOUR ACCESS KEY SECRET HERE>
Default Region Id [None]: cn-hongkong
Default output format [None]: json
```

Once succeed, all ecs command will be available to run with json responses. For example `$ aliyuncli ecs DescribeRegions` may retrieve all available regions in json:

```
$ aliyuncli ecs DescribeRegions
{
    "Regions": {
        "Region": [
            {
                "LocalName": "\u534e\u5357 1", 
                "RegionId": "cn-shenzhen"
            }, 
            ...
            {
                "LocalName": "\u7f8e\u56fd\u897f\u90e8 1 (\u7845\u8c37)", 
                "RegionId": "us-west-1"
            }
        ]
    }, 
    "RequestId": "A7CCE1DD-F298-495B-99D3-CCD5662C5E66"
}

```

# Create Instance

Before creating instances, user must create security groups by themselve.

Using `aliyuncli ecs CreateInstance` to create a new instance. Please check the [parameter details](https://intl.aliyun.com/help/doc-detail/25499.htm). Here is an example:

```
aliyuncli ecs CreateInstance \
--InstanceChargeType PostPaid \
--Period 1 \
--RegionId cn-hongkong \
--InstanceType ecs.n1.tiny \
--InternetChargeType PayByTraffic \
--InternetMaxBandwidthIn 1 \
--InternetMaxBandwidthOut 1 \
--ImageId "ubuntu_16_0402_64_40G_base_20170222.vhd" \
--SecurityGroupId "sg-j6c2v0moqn05gl1sbzxr" \
--Password Abcd1234 \
--Tag1Key "Perfect" \
--Tag1Value "PerfectPrebuilt" \
--InstanceName "MyFirstPerfectOnAliyun" \
--AccessKeyID LTAXXXXXXXXXXXXX \
--AccessKeySecret j0kWYYYYYYYYYYYYYYYYYYYY
```
In this example, an instance will be created as a post paid one with billing period of one month as defined in the first two parameters, i.e., "InstanceChargeType" and "Period", with a password for `root` user. Not that password must be a string of 8 to 30 characters. It must contain uppercase/lowercase letters and numerals, but cannot contain special symbols.

If success, it will return the InstanceId:

```
{
    "InstanceId": "i-j6cg1mzgwsm6176dek5j", 
    "RequestId": "EE1BDF95-0917-484C-84D5-8A27775FFF61"
}
```

run command ` aliyuncli ecs DescribeInstances --RegionId cn-hongkong` will find the instances.

# Start Instance

As the previous example, command line `aliyuncli ecs StartInstance --InstanceId "i-j6cg1mzgwsm6176dek5j"` will start the instance

JSON key `IpAddress` will reflect the public ip, then you can `ssh root@a.b.c.d` to connect.

# Stop Instance

Same instance `aliyuncli ecs StopInstance --InstanceId "i-j6cg1mzgwsm6176dek5j" --ForceStop` will fully stop the instance. User can go back to the dashboard and click "Release Setting" to terminate / delete the instance.

# Issues

1. Region `us-east-1` has only classic network other than VPC, so I chose `cn-hongkong` instead


