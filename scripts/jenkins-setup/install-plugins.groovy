import jenkins.model.Jenkins

def uc = Jenkins.instance.updateCenter
uc.updateAllSites()

def plugins = ['ssh-agent', 'ansicolor']
plugins.each { name ->
    def plugin = uc.getPlugin(name)
    if (plugin) {
        println("INSTALLING: " + name)
        def deployment = plugin.deploy(true)
        deployment.get()
        println("INSTALLED: " + name)
    } else {
        println("NOT_FOUND: " + name)
    }
}
println("DONE")
