import sys
content = open(sys.argv[1]).read()
old = 'docker ps --filter "name=karmada-host" --filter "name=member-1" --format "table {{.Names}}\t{{.Status}}\t{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}"'
new = 'docker ps --filter "name=karmada-host" --filter "name=member-1" --format "table {{.Names}}\t{{.Status}}"'
open(sys.argv[1], 'w').write(content.replace(old, new))
