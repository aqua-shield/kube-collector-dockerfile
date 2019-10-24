@Library('aqua-pipeline-lib@master')_
pipeline {
  environment {
    registry = "registry.aquasec.com"
    registryCredential = 'registry-credentials'
    dockerRepository = 'kube-collector'
    dockerImageTag = 'web'
    CREATE_NEW_GIT_BRANCH_FOR_TARGET = true
    AWS_ACCESS_KEY_ID = credentials('jenkinsAwsAccessKeyId')
    AWS_SECRET_ACCESS_KEY = credentials('jenkinsAwsSecretAccessKey')
    AUTOMATION_DOCKERHUB_PASSWORD = credentials('automationaquaDockerHubpassword')
    AZURE_ACR_PASSWORD = credentials('aquasecAzureACRpassword')
    GIT_PASS = credentials('gitPass')
  }
  agent any
  stages {
    stage('Fetching Dockerfile') {
      steps {
        git 'https://aqua-shield:Xhxnv1234!@github.com/aqua-shield/kube-collector-dockerfile.git'
      }
    }
    stage('Building Image') {
      steps{
        script {
          dockerImage = docker.build("$registry/$dockerRepository:$dockerImageTag", "--build-arg CACHEBUST=\$(date +%s) .") // ":$BUILD_NUMBER"
        }
      }
    }
    node('build_machines'){
            timeout(120) {
                HOST_NAME = sh(script: "hostname", returnStdout: true).replaceAll("\\s","")
                ansiColor('xterm') {
                    wrap([$class: 'BuildUser']) {
                        triggered_by = env.BUILD_USER
                    }
                    build_version_original = build_version
                    parallel (
                        linux_build: { 
                            sh 'sudo chown -R ubuntu:ubuntu .'
                            deleteDir()
                            stage('Clone Code') {
                                
								sh "git clone --depth 1 -b ${branch} https://eranbibi:${gitPass}@bitbucket.org/scalock/server.git ."
                                sh "git clone --depth 1 -b master https://eranbibi:${gitPass}@bitbucket.org/scalock/devops.git"

                                writeFile file: env.WORKSPACE+"/branch", text: branch+"\n"
                                
                                update_release_version = sh(script: """echo $build_version | awk -F "." '{print \$1"."\$2}'| sed \"s/\$/.\$(date +%y%j)/\"""", returnStdout: true).replaceAll("\\s","")
                                if (build_version.startsWith("4.") || build_version.startsWith("3.5")){
                                    build_version = update_release_version
                                }

                                COMMIT_NUM = sh(script: 'git rev-parse --short HEAD', returnStdout: true).replaceAll("\\s","")

                                getReleaseScript version: build_version, path: "common/genver/main.go"

                                if (skip_integration_tests == "true" || skip_aqua_scan == "true") {
                                    currentBuild.displayName = build_version+".b"+env.BUILD_ID+".("+COMMIT_NUM+").skipped_tests.("+triggered_by+")."+branch
                                    release_name = build_version+".b"+env.BUILD_ID+"."+COMMIT_NUM+".skipped_tests"
                                    ready_for_release = false
                                }else{
                                    currentBuild.displayName = build_version+".b"+env.BUILD_ID+".("+COMMIT_NUM+").("+triggered_by+")."+branch
                                    release_name = build_version+".b"+env.BUILD_ID+"."+COMMIT_NUM
                                    ready_for_release = true
                                }
                                sh 'git submodule update --init'
                            }
                            stage('Build'){
                                
                                    build_script_dir = sh(script: 'find *build -maxdepth 0 -type d|head -n1', returnStdout: true).replaceAll("\\s","")
                                    if (build_script_dir != "") {
                                        echo '\033[1;33m[Info]    \033[0m Docker Login'
                                        sh './'+build_script_dir+'/scripts/docker_login.sh'
                                        echo '\033[1;33m[Info]    \033[0m Create Build Tags'
                                        sh './'+build_script_dir+'/scripts/create_build_tags.sh'
                                        echo '\033[1;33m[Info]    \033[0m Create Build Docker Image'
                                        sh './'+build_script_dir+'/scripts/create_build_image.sh'
                                        echo '\033[1;33m[Info]    \033[0m Compile Code'  
                                        sh './'+build_script_dir+'/scripts/compile_code.sh'
                                        echo '\033[1;33m[Info]    \033[0m Build Docker Images' 
                                        sh './'+build_script_dir+'/scripts/build_image.sh'
                                    }else{
                                        sh "docker login -u aquadev -p ${aquadevAzureACRpassword} aquadev.azurecr.io"
                                        try {
                                            echo "Info: Downloading nanoenforcer lib for serverless runtime"
                                            sh "wget -q --user ${auth0_user} --password ${auth0_pass} https://download.aquasec.com/nanoenforcer/${build_version_original}/slklib.so"
                                            sh "wget -q --user ${auth0_user} --password ${auth0_pass} https://download.aquasec.com/nanoenforcer/${build_version_original}/lambda-hooks.so"
                                        }catch(e){
                                            echo "Error: Unable to locate slklib.so or lambda-hooks.so for ${build_version_original}"
                                        }
                                        if (fileExists('./nanoenforcer/java/')) {
                                            echo "Info: Compiling nanoenforcer for Java"
                                            try {
                                                sh "docker run -u 1000:1000 --rm -v `pwd`/nanoenforcer/java/:/build openjdk:8-jdk bash -c 'cd /build; javac Aqua.java; jar cmf META-INF/MANIFEST.MF nanoenforcer.jar Aqua.class'"
                                            }catch(e){
                                                echo "Error: Unable to compile nanoenforcer for Java"
                                            }
                                        }
                                        try{
                                            echo '\033[1;33m[Info]    \033[0m Build'
                                            sh './build'
                                        }catch(e){
                                            notifyBuild("build step")
                                            error("Error with Build step")
                                        }
                                        if (fileExists('./test')) {
                                            try{
                                                echo '\033[1;33m[Info]    \033[0m Unit-Tests'
                                                sh './test'
                                            }catch(e){
                                                notifyBuild("unit-tests step")
                                                error("Error with unit-tests step")
                                            }                                            
                                        }
                                        try{
                                            echo '\033[1;33m[Info]    \033[0m Package'
                                            build_date = sh(script: 'date +%Y-%m-%dT%T', returnStdout: true).replaceAll("\\s","")
                                            sh "BUILD_DATE=${build_date} VERSION=${build_version} COMMIT=${COMMIT_NUM} ./package"
                                        }catch(e){
                                            notifyBuild("packaging step")
                                            error("Error with packaging step")
                                        }
                                    }
    
                            }
                        },
                        windows_build: {
                            build_version = build_version_original
                            if (skip_windows_scanner_cli_build == "false") {
                                try{
                                        build job: "build_scanner_windows_"+build_version.take(3)+".x_pipeline", parameters: [
                                        string(name: 'branch', value: branch),
                                        string(name: 'build_version', value: build_version)]
                                }catch(e){
                                    notifyBuild("windows build step")
                                    error("Error with Windows Build step")                                    
                                }
                            }
                        }
                    )
                    stage('Test: Run Aqua Scan'){
                        if (skip_aqua_scan == "false") {
                            def buildResult = 'success'
                            echo '\033[1;33m[Info]    \033[0m Running Aqua Scan'
                            try{
                                aqua locationType: 'local', localImage: 'aquadev/server:'+branch, hideBase: false, notCompliesCmd: '', onDisallowed: 'fail', showNegligible: false
                                aqua locationType: 'local', localImage: 'aquadev/gateway:'+branch, hideBase: false, notCompliesCmd: '', onDisallowed: 'fail', showNegligible: false
                                aqua locationType: 'local', localImage: 'aquadev/database:'+branch, hideBase: false, notCompliesCmd: '', onDisallowed: 'fail', showNegligible: false		
                                aqua locationType: 'local', localImage: 'aquadev/scanner-cli:'+branch, hideBase: false, notCompliesCmd: '', onDisallowed: 'fail', showNegligible: false
                                aqua locationType: 'local', localImage: 'aquadev/csp:'+branch, hideBase: false, notCompliesCmd: '', onDisallowed: 'pass', showNegligible: false
                            }catch(e){
                                    notifyBuild("Aqua CSP scan step")
                                    error("Error with Aqua CSP Scan")                                    
                            }
                        } else {
                            echo '\033[1;33m[Info]    \033[0m Skipping Aqua Scan'    
                        }
                    }

                    if (skip_integration_tests == "false" || skip_ui_verification == "false") {
                        echo '\033[1;33m[Info]    \033[0m Running Aqua Console for Testing'
                        try{
                            sh "docker rm -fv aqua-csp-ci"
                        }catch(e){
                        }
                        try{
                            sh "docker run -d -p 5433:5432 -p 8088:8080 --name aqua-csp-ci -e AQUA_GRPC_PORT=8449 -e ADMIN_PASSWORD=password -e SCALOCK_LOG_LEVEL=DEBUG -e LICENSE_TOKEN=${aquaDevLicense} -v /var/run/docker.sock:/var/run/docker.sock aquadev/csp:${branch}"
                            sleep 20
                        }catch(e){
                            notifyBuild("running csp inatance for testing")
                            error("Unable to start Aqua CSP")
                        }                       
                    }
    /*
    stage('Deploy Image') {
      steps{
          
        script {
            env.DEST_REPO = 'aquasec.azurecr.io'
            env.jenkinsAwsSecretAccessKey = env.AWS_SECRET_ACCESS_KEY
            env.jenkinsAwsAccessKeyId = env.AWS_ACCESS_KEY_ID
            env.automationaquaDockerHubpassword = env.AUTOMATION_DOCKERHUB_PASSWORD
            env.aquasecAzureACRpassword = env.AZURE_ACR_PASSWORD
            env.gitPass = env.GIT_PASS
            sh "${env.scripts_home}/release/push_aqua_to_aquasec.sh ${env.DEST_REPO} $registry/$dockerRepository:$dockerImageTag"
        }
      }
    }
    */
    stage('Remove Unused docker image') {
      steps{
        sh "docker rmi $registry/$dockerRepository:$dockerImageTag" //:$BUILD_NUMBER"
      }
    }
  }
}