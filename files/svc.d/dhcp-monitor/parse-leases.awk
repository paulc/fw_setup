
BEGIN {
		i = 0
		"TZ=UTC date '+%Y/%m/%d %H:%M:%S'" | getline now
}

/^lease/ { 
		while (getline l == 1) {
			if (l ~ "abandoned") break
			if (l == "}") {
                            if (client != "") {
                                lease[$2] = client
                            } 
                            break
                        }
			if (l ~ "ends") {
				split(l,a," ")
				if (a[3]" "a[4] < now) {
					break
				}
			}
			if (l ~ "client-hostname") {
				split(l,a,"[ ;]")
				client = a[2]
				gsub("\"","",client)
				gsub(" ","_",client)
			}
		}
}

END {
		for (ip in lease) {
			printf("%-24s 600 A    %s\n",lease[ip],ip)
		}
}
	
