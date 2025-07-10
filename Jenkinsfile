pipeline {
  agent any

  environment {
    SONAR_URL = 'http://ec2-13-202-47-19.ap-south-1.compute.amazonaws.com:15998/'
    SONAR_PROJECT = 'docker-springboot'
    EMAIL_RECIPIENT = 'p.khilare@accenture.com'
    SERVICE_NAME = 'springboot-app'
    DOCKER_HUB_REPO = 'priyanka015/springboot'
    KUBECONFIG = "/var/lib/jenkins/.kube/config"
    MINIKUBE_HOME = '/var/lib/jenkins'
  }

  stages {
    stage('Checkout Code') {
      steps {
        git branch: 'main', credentialsId: 'github-token', url: 'https://github.com/khilarepriya/docker-springboot.git'
      }
    }

    stage('Detect Language') {
      steps {
        script {
          if (fileExists('pom.xml')) {
            env.PROJECT_LANG = 'java'
          } else if (fileExists('package.json')) {
            env.PROJECT_LANG = 'nodejs'
          } else if (fileExists('requirements.txt') || fileExists('pyproject.toml')) {
            env.PROJECT_LANG = 'python'
          } else if (!sh(script: "ls *.csproj", returnStatus: true)) {
            env.PROJECT_LANG = 'dotnet'
          } else {
            error("Unsupported project type.")
          }
          echo "Detected language: ${env.PROJECT_LANG}"
        }
      }
    }

    stage('SonarQube Scan') {
      steps {
        script {
          withSonarQubeEnv('SonarQube') {
            if (env.PROJECT_LANG == 'java') {
              sh 'mvn clean compile sonar:sonar -Dsonar.java.binaries=target/classes'
            } else if (env.PROJECT_LANG == 'python' || env.PROJECT_LANG == 'nodejs') {
              sh "sonar-scanner -Dsonar.projectKey=${SONAR_PROJECT} -Dsonar.sources=. -Dsonar.host.url=${SONAR_URL}"
            } else if (env.PROJECT_LANG == 'dotnet') {
              withCredentials([string(credentialsId: 'sonarqube-token-new', variable: 'SONAR_TOKEN')]) {
                sh '''
                  export PATH=$PATH:$HOME/.dotnet/tools
                  dotnet tool install --global dotnet-sonarscanner || true
                  dotnet restore
                  dotnet sonarscanner begin /k:"''' + SONAR_PROJECT + '''" /d:sonar.host.url=''' + SONAR_URL + ''' /d:sonar.login=$SONAR_TOKEN
                  dotnet build || { echo "[ERROR] Build failed!"; exit 1; }
                  dotnet sonarscanner end /d:sonar.login=$SONAR_TOKEN
                '''
              }
            }
          }
        }
      }
    }

    stage('Snyk Scan') {
      steps {
        withCredentials([string(credentialsId: 'snyk-token01', variable: 'SNYK_TOKEN')]) {
          script {
            if (env.PROJECT_LANG == 'python') {
              sh '''
                python3 -m venv venv
                . venv/bin/activate
                pip install -r requirements.txt || true
                snyk auth $SNYK_TOKEN
                snyk test --file=requirements.txt --package-manager=pip --severity-threshold=high || true
                snyk monitor --file=requirements.txt --package-manager=pip
              '''
            } else if (env.PROJECT_LANG == 'java') {
              sh '''
                snyk auth $SNYK_TOKEN
                snyk test --file=pom.xml --package-manager=maven --severity-threshold=high || true
                snyk monitor --file=pom.xml --package-manager=maven
              '''
            } else if (env.PROJECT_LANG == 'nodejs') {
              sh '''
                npm install
                snyk auth $SNYK_TOKEN
                snyk test --file=package.json --package-manager=npm --severity-threshold=high || true
                snyk monitor --file=package.json --package-manager=npm
              '''
            } else if (env.PROJECT_LANG == 'dotnet') {
              sh '''
                snyk auth $SNYK_TOKEN
                dotnet restore
                snyk test --all-projects --severity-threshold=high || true
                snyk monitor --all-projects
              '''
            }
          }
        }
      }
    }

    stage('Unit Test with Testcontainers') {
      steps {
        script {
          if (env.PROJECT_LANG == 'java') {
            sh '''
              mvn clean test
            '''
          } else if (env.PROJECT_LANG == 'python') {
            sh '''#!/bin/bash
              set -e  # Fail fast on any error
              rm -rf venv
              python3 -m venv venv
              source venv/bin/activate
              
              # Install all required packages including testcontainers
              pip install --upgrade pip
              pip install -r requirements.txt
              pip install testcontainers

              # Set PYTHONPATH to ensure 'src' folder is recognized as a module
              export PYTHONPATH=$PWD
              
              # Run unit tests
              pip install pytest
              pytest
            '''
          } else if (env.PROJECT_LANG == 'nodejs') {
            sh '''
              npm install
              npm install --save-dev jest testcontainers
              npx jest
            '''
          } else if (env.PROJECT_LANG == 'dotnet') {
            sh '''
              dotnet restore
              dotnet test
            '''
          } else {
            error("Unsupported language for unit testing.")
          }
        }
      }
    }
    
    stage('Stop Service Before Deployment') {
      steps {
        echo "Stopping service ${SERVICE_NAME} before deployment..."
        sh "sudo systemctl stop ${SERVICE_NAME}.service || true"
      }
    }

    stage('Docker Build & Push to Docker Hub') {
      steps {
        script {
          env.IMAGE_NAME = "${DOCKER_HUB_REPO}:${BUILD_ID}"

          withCredentials([usernamePassword(
            credentialsId: 'docker-hub-credentials',
            usernameVariable: 'DOCKER_USER',
            passwordVariable: 'DOCKER_PASS'
          )]) {
            sh '''
              echo "🧪 Building Java project..."
              mvn clean package -DskipTests || { echo '❌ Maven build failed'; exit 1; }

              echo "🔍 Checking for JAR file..."
              ls -l target/*.jar || { echo '❌ No JAR file found in target/'; exit 1; }

              echo "🐳 Logging into Docker Hub..."
              echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin || { echo '❌ Docker login failed'; exit 1; }

              echo "📦 Building Docker image: $IMAGE_NAME"
              docker build -t $IMAGE_NAME . || { echo '❌ Docker build failed'; exit 1; }

              echo "📤 Pushing Docker image to Docker Hub..."
              docker push $IMAGE_NAME || { echo '❌ Docker push failed'; exit 1; }

              echo "✅ Docker image pushed successfully!"

              echo "⚙️ Generating systemd service from template..."
              sed "s/__BUILD_ID__/${BUILD_ID}/g" /etc/systemd/system/springboot-app-template.service | sudo tee /etc/systemd/system/springboot-app.service
              sudo systemctl daemon-reload
              sudo systemctl restart springboot-app

            '''
          }
        }
      }
    }
   
    stage('Start Service After Deployment') {
      steps {
        echo "Starting service ${SERVICE_NAME} after deployment..."
        sh "sudo systemctl start ${SERVICE_NAME}.service"
      }
    }

    stage('Deploy to Kubernetes (Minikube)') {
      steps {
        script {
          def deployManifest = """
          apiVersion: apps/v1
          kind: Deployment
          metadata:
            name: ${env.PROJECT_LANG}-app
          spec:
            replicas: 1
            selector:
              matchLabels:
                app: ${env.PROJECT_LANG}-app
            template:
              metadata:
                labels:
                  app: ${env.PROJECT_LANG}-app
              spec:
                containers:
                - name: ${env.PROJECT_LANG}-container
                  image: ${env.IMAGE_NAME}
                  ports:
                  - containerPort: 80
          """
          writeFile file: 'deploy.yaml', text: deployManifest
          
          // Start Minikube if not running and apply manifest
          sh '''
            echo "➡️  Starting or checking Minikube..."
            export MINIKUBE_HOME=/var/lib/jenkins
            export KUBECONFIG=/var/lib/jenkins/.kube/config

            CURRENT_VERSION=$(minikube status --format '{{.Kubeconfig.Version}}' 2>/dev/null || echo "none")
            echo "🌀 Current Minikube K8s version: $CURRENT_VERSION"

            if [[ "$CURRENT_VERSION" != "v1.27.4" ]]; then
              echo "⚠️ Recreating Minikube with required version..."
              minikube delete || true
              minikube start --kubernetes-version=v1.27.4 --cpus=2 --memory=8192 --driver=docker
            else
              minikube start
            fi

            echo "✅ Using KUBECONFIG at $KUBECONFIG"
            kubectl config use-context minikube
            kubectl cluster-info
          '''
        }
      }
    }

    stage('Sanity Test') {
      steps {
        script {
          sh """
            echo "Waiting for service to stabilize..."
            sleep 10

            echo "Checking systemd service status for: ${SERVICE_NAME}.service"
            sudo systemctl status ${SERVICE_NAME}.service || exit 1

            echo "Performing sanity check via curl..."
            if curl -f http://localhost:7070/health; then
              echo "Sanity check passed"
            else
              echo "Sanity check failed"
              exit 1
            fi
          """
        }
      }
    }


  post {
    always {
      mail to: "${EMAIL_RECIPIENT}",
           subject: "CI/CD Pipeline Report for ${env.JOB_NAME}",
           body: """\
Hello,

The pipeline has completed.

🔍 SonarQube Report: ${SONAR_URL}dashboard?id=${SONAR_PROJECT}  
📦 Snyk Project Page: https://app.snyk.io/org/your-org/project?q=${SONAR_PROJECT}

Please review for any issues.

Thanks,  
Jenkins Pipeline
"""
      cleanWs()
    }
  }
}
