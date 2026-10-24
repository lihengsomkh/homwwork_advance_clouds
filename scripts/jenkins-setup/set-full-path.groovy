import hudson.slaves.EnvironmentVariablesNodeProperty
import jenkins.model.Jenkins

def instance = Jenkins.getInstance()
def globalNodeProperties = instance.getGlobalNodeProperties()
def envVarsNodePropertyList = globalNodeProperties.getAll(EnvironmentVariablesNodeProperty.class)
EnvironmentVariablesNodeProperty prop = envVarsNodePropertyList.get(0)
def envVars = prop.getEnvVars()

def extra = 'C:\\Users\\li\\AppData\\Local\\Programs\\DockerDesktop\\resources\\bin;C:\\Program Files\\Git\\bin;C:\\Program Files\\Git\\usr\\bin;'
def current = System.getenv('PATH') ?: ''
envVars.put('PATH', extra + current)
instance.save()
println('SUCCESS_SET_PATH')
