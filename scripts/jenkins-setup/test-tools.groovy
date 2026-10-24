try {
    def proc = ['cmd', '/c', 'docker', '--version'].execute()
    proc.waitFor()
    println('DOCKER: ' + proc.text.trim())
} catch (Exception e) {
    println('DOCKER ERROR: ' + e.message)
}

try {
    def shProc = ['sh', '--version'].execute()
    shProc.waitFor()
    println('SH: ' + (shProc.text.trim().split('\n')[0]))
} catch (Exception e) {
    println('SH ERROR: ' + e.message)
}
