import jenkins.model.Jenkins
import hudson.tasks.Shell

def descriptor = Jenkins.instance.getDescriptorByType(Shell.DescriptorImpl.class)
descriptor.setShell('C:\\Program Files\\Git\\bin\\sh.exe')
descriptor.save()
println('SHELL CONFIGURED: ' + descriptor.getShell())
