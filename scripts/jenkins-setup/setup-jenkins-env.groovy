import hudson.slaves.EnvironmentVariablesNodeProperty
import jenkins.model.Jenkins

def instance = Jenkins.getInstance()
def globalNodeProperties = instance.getGlobalNodeProperties()
def envVarsNodePropertyList = globalNodeProperties.getAll(EnvironmentVariablesNodeProperty.class)

EnvironmentVariablesNodeProperty envVarsNodeProperty = null
if (envVarsNodePropertyList == null || envVarsNodePropertyList.isEmpty()) {
    envVarsNodeProperty = new EnvironmentVariablesNodeProperty()
    globalNodeProperties.add(envVarsNodeProperty)
} else {
    envVarsNodeProperty = envVarsNodePropertyList.get(0)
}

def envVars = envVarsNodeProperty.getEnvVars()
// Add Docker and Git bin to PATH
def dockerPath = 'C:\\Users\\li\\AppData\\Local\\Programs\\DockerDesktop\\resources\\bin'
def gitBinPath = 'C:\\Program Files\\Git\\bin'
def gitUsrBinPath = 'C:\\Program Files\\Git\\usr\\bin'
envVars.put('PATH+DOCKER', dockerPath)
envVars.put('PATH+GITBIN', gitBinPath)
envVars.put('PATH+GITUSR', gitUsrBinPath)
instance.save()
println('SUCCESS_CONFIGURED')
