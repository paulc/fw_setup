
BEGIN {
        n = match(R,".*/")
        split(substr(R,RLENGTH+1),a,"\.")
        fwd = sprintf("^%d.%d.%d",a[3],a[2],a[1])
        while (getline <Z) {
            if ($4 ~ fwd) {
                printf("%d     600 PTR %s.%s\n",substr($4,length(fwd)+1),$1,D)
            }
        }
}
