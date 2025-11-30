Import-Module -DisableNameChecking -Force $PSScriptRoot/test_helpers.psm1

$global:IMAGE_NAME = Get-EnvOrDefault 'IMAGE_NAME' '' # Ex: jenkins4eval/ssh-agent:nanoserver-ltsc2019-jdk17
$global:JAVA_VERSION = Get-EnvOrDefault 'JAVA_VERSION' ''

Write-Host "= TESTS: Preparing $global:IMAGE_NAME with Java $global:JAVA_VERSION"

$imageItems = $global:IMAGE_NAME.Split(':')
$global:IMAGE_TAG = $imageItems[1]

$items = $global:IMAGE_TAG.Split('-')
# Remove the 'jdk' prefix
$global:JAVAMAJORVERSION = $items[2].Remove(0,3)
$global:WINDOWSFLAVOR = $items[0]
$global:WINDOWSVERSIONTAG = $items[1]
$global:TOOLSWINDOWSVERSION = $items[1]
# There are no eclipse-temurin:*-ltsc2019 or mcr.microsoft.com/powershell:*-ltsc2019 docker images unfortunately, only "1809" ones
if ($items[1] -eq 'ltsc2019') {
    $global:TOOLSWINDOWSVERSION = '1809'
}

# TODO: make this name unique for concurency
$global:CONTAINERNAME = 'pester-jenkins-ssh-agent-{0}' -f $global:IMAGE_TAG

$global:CONTAINERSHELL = 'powershell.exe'
if($global:WINDOWSFLAVOR -eq 'nanoserver') {
    $global:CONTAINERSHELL = 'pwsh.exe'
}

$global:PUBLIC_SSH_KEY = 'ssh-rsa AAAAB3NzaC1yc2EAAAABJQAAAQEAvnRN27LdPPQq2OH3GiFFGWX/SH5TCPVePLR21ngMFV8nAthXgYrFkRi/t+Wafe3ByTu2XYUDlXHKGIPIoAKo4gz5dIjUFfoac1ZuCDIbEiqPEjkk4tkfc2qr/BnIZsOYQi4Mbu+Z40VZEsAQU7eBinnZaHE1qGMHjS1xfrRtp2rdeO1EBz92FJ8dfnkUnohTXo3qPVSFGIPbh7UKEoKcyCosRO1P41iWD1rVsH1SLLXYAh2t49L7IPiplg09Dep6H47LyQVbxU9eXY8yMtUrRuwEk9IUX/IqpxNhk5hngHPP3JjsP0hyyrYSPkZlbs3izd9kk3y09Wn/ElHidiEk0Q=='
$global:PRIVATE_SSH_KEY = @"
-----BEGIN RSA PRIVATE KEY-----
MIIEoQIBAAKCAQEAvnRN27LdPPQq2OH3GiFFGWX/SH5TCPVePLR21ngMFV8nAthX
gYrFkRi/t+Wafe3ByTu2XYUDlXHKGIPIoAKo4gz5dIjUFfoac1ZuCDIbEiqPEjkk
4tkfc2qr/BnIZsOYQi4Mbu+Z40VZEsAQU7eBinnZaHE1qGMHjS1xfrRtp2rdeO1E
Bz92FJ8dfnkUnohTXo3qPVSFGIPbh7UKEoKcyCosRO1P41iWD1rVsH1SLLXYAh2t
49L7IPiplg09Dep6H47LyQVbxU9eXY8yMtUrRuwEk9IUX/IqpxNhk5hngHPP3Jjs
P0hyyrYSPkZlbs3izd9kk3y09Wn/ElHidiEk0QIBJQKCAQEAlUZmiZoHWUnAt9Oz
1jXAiYdLi9ih8kPGZu5PTia9XNvgTlaJxmXZHrKIbYpyK1l8NfCIBBwlZ0tZNc8S
3kdGGPVpkrBu4MryIwxkFELyn4kkB104lh/MiuTnqeqx1AEWeQ9V2mjEuQzXHIiy
2dUEqs40x3tTkdETwa3/AnG9upCsS8DpUmBa50hHvkc8pfmDrCbDAB7QjrgxAv7N
TjZQz1BslDnqULBs0weqD/YG60Vxdbu8ULHcMKYHmlk06a2lxF2A+CbvC+eLyD5B
+YHsD2CnpNhmBxLXfjnKuMhT6ybtop1hZW4zy0jLsyvAgM/kSb/iH9XJ17nfdlMm
NChQcQKBgQDvKs+81jDhoP+fZXi7bnVwlo2UzuTXNkUO1fLCFHWpJXMXu4wY6iMY
klEjXmN68Ijj0n3Enw7yM4/HBcnvRlw78zbDbKxwz5WRVc8w4/Ct4z8TX9Il1srR
Qa9vPhju8KazY1XxNMidMJmcR6cjG7glzKorE9faHc9aIskPP93y1wKBgQDL288f
tk0F/RcikCnfq8Ligm3GkZfP7lyf0T9lXHg0Qe9d3esvVHe02blMGm0vgsKy4Aip
jlyyM8ExI5yF2zUbOqLxDhWWqL6EnlYXEI4s5h/4AJOPrERGdOU/Ix7G312mqcmi
FlRVug8II64O7IgVU6pWyckOSMf6llyH/ItYlwKBgDotAhktLnwSZ7EmhSasKmd+
kSQyU1bxhmtkeVHNoBRjDiheDVIrHUsqgnBjEUdq8N14Y8gLA6KymJgx1yxdOQep
3ONtdg2aRvnWmi58olPPfguhr6hW12NVKqxbNn9PSyS3TEGXN7eIXLdPswiKM7Yq
3Ui/ozUOK4SgrXJpey07AoGAG4xoGQrMI2dj/cB0XH7+qPzeZvEUg+Hw11OgyIIe
FOZQx37al7F39dg7ooAcl7e5ch5GXBooM8HN/7i0SXCmT8mnUQHnPd9zsQ56ViTU
8U+Hx5FgDH8QJTJkKyBr8Vx0cHfPI73UC5WvARmUD9rGSBI5nQaC9BesUkuro6yB
iIMCgYAnlf3vd9/s8izGoHH1K2MJgGQT06Wn4ESjKpqqayqiXHccHGgeXeAiONa1
uiWcmBF4XtMTVXUGcS6DCm/jf/4JDI8B1eJCVQKLbZXZbENWnptDtj098NTt9NdV
TUwLP4n7pK4J2sCIs6fRD5kEYms4BnddXeRuI2fGZHGH70Ci/Q==
-----END RSA PRIVATE KEY-----
"@

$global:GITLFSVERSION = '3.7.1'

Cleanup($global:CONTAINERNAME)

Describe "[$global:IMAGE_TAG] image can be built" {
    It 'builds image' {
        $exitCode, $stdout, $stderr = Run-Program 'docker' "build --build-arg `"WINDOWS_VERSION_TAG=${global:WINDOWSVERSIONTAG}`" --build-arg `"TOOLS_WINDOWS_VERSION=${global:TOOLSWINDOWSVERSION}`" --build-arg `"JAVA_VERSION=${global:JAVA_VERSION}`" --build-arg `"JAVA_HOME=C:\openjdk-${global:JAVAMAJORVERSION}`" --tag=${global:IMAGE_TAG} --file ./windows/${global:WINDOWSFLAVOR}/Dockerfile ."
        $exitCode | Should -Be 0
    }
}

Describe "[$global:IMAGE_TAG] image has setup-sshd.ps1 in the correct location" {
    BeforeAll {
        $exitCode, $stdout, $stderr = Run-Program 'docker' "run --detach --tty --name=`"$global:CONTAINERNAME`" --publish-all `"$global:IMAGE_NAME`" `"$global:CONTAINERSHELL`""
        $exitCode | Should -Be 0
        Is-ContainerRunning $global:CONTAINERNAME | Should -BeTrue
    }

    It 'has setup-sshd.ps1 in C:/ProgramData/Jenkins' {
        $exitCode, $stdout, $stderr = Run-Program 'docker' "exec $global:CONTAINERNAME $global:CONTAINERSHELL -C `"if(Test-Path C:/ProgramData/Jenkins/setup-sshd.ps1) { exit 0 } else { exit 1}`""
        $exitCode | Should -Be 0
    }

    AfterAll {
        Cleanup($global:CONTAINERNAME)
    }
}

Describe "[$global:IMAGE_TAG] image has no pre-existing SSH host keys" {
    BeforeAll {
        $exitCode, $stdout, $stderr = Run-Program 'docker' "run --detach --tty --name=`"$global:CONTAINERNAME`" --publish-all `"$global:IMAGE_NAME`" `"$global:CONTAINERSHELL`""
        $exitCode | Should -Be 0
        Is-ContainerRunning $global:CONTAINERNAME | Should -BeTrue
    }

    It 'has has no SSH host key present in C:\ProgramData\ssh' {
        $exitCode, $stdout, $stderr = Run-Program 'docker' "exec $global:CONTAINERNAME $global:CONTAINERSHELL -C `"if(Test-Path C:/ProgramData/ssh/ssh_host*_key*) { exit 0 } else { exit 1 }`""
        $exitCode | Should -Be 1
    }

    AfterAll {
        Cleanup($global:CONTAINERNAME)
    }
}

Describe "[$global:IMAGE_TAG] checking image metadata" {
    It 'has correct volumes' {
        $exitCode, $stdout, $stderr = Run-Program 'docker' "inspect --format '{{.Config.Volumes}}' $global:IMAGE_NAME"
        $exitCode | Should -Be 0

        $stdout | Should -Match 'C:/Users/jenkins/AppData/Local/Temp'
        $stdout | Should -Match 'C:/Users/jenkins/Work'
    }

    It 'has the source GitHub URL in docker metadata' {
        $exitCode, $stdout, $stderr = Run-Program 'docker' "inspect --format=`"{{index .Config.Labels \`"org.opencontainers.image.source\`"}}`" $global:IMAGE_NAME"
        $exitCode | Should -Be 0
        $stdout.Trim() | Should -Match 'https://github.com/jenkinsci/docker-ssh-agent'
    }
}

Describe "[$global:IMAGE_TAG] image has correct version of java and git-lfs installed and in the PATH" {
    BeforeAll {
        $exitCode, $stdout, $stderr = Run-Program 'docker' "run --detach --tty --name=`"$global:CONTAINERNAME`" --publish-all `"$global:IMAGE_NAME`" `"$global:PUBLIC_SSH_KEY`""
        $exitCode | Should -Be 0
        Is-ContainerRunning $global:CONTAINERNAME
    }

    It 'has java installed and in the path' {
        $exitCode, $stdout, $stderr = Run-Program 'docker' "exec $global:CONTAINERNAME $global:CONTAINERSHELL -C `"if(`$null -eq (Get-Command java.exe -ErrorAction SilentlyContinue)) { exit -1 } else { exit 0 }`""
        $exitCode | Should -Be 0

        $exitCode, $stdout, $stderr = Run-Program 'docker' "exec $global:CONTAINERNAME $global:CONTAINERSHELL -C `"`$version = java -version 2>&1 ; Write-Host `$version`""
        $r = [regex] "^openjdk version `"(?<major>\d+)"
        $m = $r.Match($stdout)
        $m | Should -Not -Be $null
        $m.Groups['major'].ToString() | Should -Be "$global:JAVAMAJORVERSION"
    }

    It 'has git-lfs (and thus git) installed and in the path' {
        $exitCode, $stdout, $stderr = Run-Program 'docker' "exec $global:CONTAINERNAME $global:CONTAINERSHELL -C `"`& git lfs env`""
        $exitCode | Should -Be 0
        $r = [regex] "^git-lfs/(?<version>\d+\.\d+\.\d+)"
        $m = $r.Match($stdout)
        $m | Should -Not -Be $null
        $m.Groups['version'].ToString() | Should -Be "$global:GITLFSVERSION"
    }

    AfterAll {
        Cleanup($global:CONTAINERNAME)
    }
}

Describe "[$global:IMAGE_TAG] create agent container with pubkey as argument" {
    BeforeAll {
        $exitCode, $stdout, $stderr = Run-Program 'docker' "run --detach --tty --name=`"$global:CONTAINERNAME`" --publish-all `"$global:IMAGE_NAME`" `"$global:PUBLIC_SSH_KEY`""
        $exitCode | Should -Be 0
        Is-ContainerRunning $global:CONTAINERNAME | Should -BeTrue
    }

    It 'runs commands via ssh' {
        $exitCode, $stdout, $stderr = Run-ThruSSH $global:CONTAINERNAME "$global:PRIVATE_SSH_KEY" "$global:CONTAINERSHELL -NoLogo -C `"Write-Host 'f00'`""
        $exitCode | Should -Be 0
        $stdout | Should -Match 'f00'
    }

    AfterAll {
        Cleanup($global:CONTAINERNAME)
    }
}

Describe "[$global:IMAGE_TAG] create agent container with pubkey as envvar" {
    BeforeAll {
        $exitCode, $stdout, $stderr = Run-Program 'docker' "run --detach --tty --name=`"$global:CONTAINERNAME`" --publish-all `"$global:IMAGE_NAME`" `"$global:PUBLIC_SSH_KEY`""
        $exitCode | Should -Be 0
        Is-ContainerRunning $global:CONTAINERNAME | Should -BeTrue
    }

    It 'runs commands via ssh' {
        $exitCode, $stdout, $stderr = Run-ThruSSH $global:CONTAINERNAME "$global:PRIVATE_SSH_KEY" "$global:CONTAINERSHELL -NoLogo -C `"Write-Host 'f00'`""
        $exitCode | Should -Be 0
        $stdout | Should -Match 'f00'
    }

    AfterAll {
        Cleanup($global:CONTAINERNAME)
    }
}


$global:DOCKER_PLUGIN_DEFAULT_ARG="/usr/sbin/sshd -D -p 22"
Describe "[$global:IMAGE_TAG] create agent container like docker-plugin with '$global:DOCKER_PLUGIN_DEFAULT_ARG' as argument" {
    BeforeAll {
        [string]::IsNullOrWhiteSpace($global:DOCKER_PLUGIN_DEFAULT_ARG) | Should -BeFalse
        $exitCode, $stdout, $stderr = Run-Program 'docker' "run --detach --tty --name=`"$global:CONTAINERNAME`" --publish-all --env=`"JENKINS_AGENT_SSH_PUBKEY=$global:PUBLIC_SSH_KEY`" `"$global:IMAGE_NAME`" `"$global:DOCKER_PLUGIN_DEFAULT_ARG`""
        $exitCode | Should -Be 0
        Is-ContainerRunning $global:CONTAINERNAME | Should -BeTrue
    }

    It 'runs commands via ssh' {
        $exitCode, $stdout, $stderr = Run-ThruSSH $global:CONTAINERNAME "$global:PRIVATE_SSH_KEY" "$global:CONTAINERSHELL -NoLogo -C `"Write-Host 'f00'`""
        $exitCode | Should -Be 0
        $stdout | Should -Match 'f00'
    }

    AfterAll {
        Cleanup($global:CONTAINERNAME)
    }
}

Describe "[$global:IMAGE_TAG] build args" {
    BeforeAll {
        Push-Location -StackName 'agent' -Path "$PSScriptRoot/.."
    }

    It 'uses build args correctly' {
        $TEST_USER = 'testuser'
        $TEST_JAW = 'C:/hamster'
        $CUSTOM_IMAGE_NAME = "custom-${IMAGE_NAME}"

        $exitCode, $stdout, $stderr = Run-Program 'docker' "build --build-arg `"WINDOWS_VERSION_TAG=${global:WINDOWSVERSIONTAG}`" --build-arg `"TOOLS_WINDOWS_VERSION=${global:TOOLSWINDOWSVERSION}`" --build-arg `"JAVA_VERSION=${global:JAVA_VERSION}`" --build-arg `"JAVA_HOME=C:\openjdk-${global:JAVAMAJORVERSION}`" --build-arg `"user=$TEST_USER`" --build-arg `"JENKINS_AGENT_WORK=$TEST_JAW`" --tag=$CUSTOM_IMAGE_NAME --file ./windows/${global:WINDOWSFLAVOR}/Dockerfile ."
        $exitCode | Should -Be 0

        $exitCode, $stdout, $stderr = Run-Program 'docker' "run --detach --tty --name=$global:CONTAINERNAME --publish-all $CUSTOM_IMAGE_NAME $global:CONTAINERSHELL"
        $exitCode | Should -Be 0
        Is-ContainerRunning "$global:CONTAINERNAME" | Should -BeTrue

        $exitCode, $stdout, $stderr = Run-Program 'docker' "exec $global:CONTAINERNAME net user $TEST_USER"
        $exitCode | Should -Be 0
        $stdout | Should -Match "User name\s*$TEST_USER"

        $exitCode, $stdout, $stderr = Run-Program 'docker' "exec $global:CONTAINERNAME $global:CONTAINERSHELL -C `"(Get-ChildItem env:\ | Where-Object { `$_.Name -eq 'JENKINS_AGENT_WORK' }).Value`""
        $exitCode | Should -Be 0
        $stdout.Trim() | Should -Match "$TEST_JAW"
    }

    AfterAll {
        Cleanup($global:CONTAINERNAME)
        Pop-Location -StackName 'agent'
    }
}
