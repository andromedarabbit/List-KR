#!/bin/bash
mapfile -t ar < domain_shortcuts.txt

reTemplate="^![[:space:]]domain_shortcut\((.*)\)[[:space:]]?$"
reDomain="^(([A-Za-z0-9]-*)*[A-Za-z0-9]+)(\.([A-Za-z0-9]-*)*[A-Za-z0-9]+)*(\.([A-Za-z]{2,}))[[:space:]]?$"
reReference="^\{(.*)\}[[:space:]]?$"

declare -A domains

for line in "${ar[@]}"
do
    if [[ $line =~ $reTemplate ]]
    then
        shortcut=${BASH_REMATCH[1]}
    elif [[ $line =~ $reDomain ]]
    then
        domain="$(echo -e "$line" | sed -e 's/[[:space:]]*$//')"
        if [ ${domains[$shortcut]+_} ]
        then
            domains[$shortcut]+=,
        fi
        domains[$shortcut]+="$domain"
    elif [[ $line =~ $reReference ]]
    then
        if [ ${domains[$shortcut]+_} ]
        then
            domains[$shortcut]+=,
        fi
        domains[$shortcut]+="${domains[${BASH_REMATCH[1]}]}"
    else
        echo "Invalid line in template"
        echo "$line"
        exit
    fi
done

files=(filter.txt unbreak.txt)
for file in ${files[@]}
do
    mapfile -t filter < $file

    for index in "${!filter[@]}"
    do
        line="$(echo -e "${filter[$index]}" | sed -e 's/[[:space:]]*$//')"

        for domain in "${!domains[@]}"
        do
            if [[ $line =~ {$domain} ]]
            then
                echo "found a matching line"
                
                replace="${domains[$domain]}"
                prepare="s/\\{"$domain"\\}(.*(#@?[%$]?#|\\$\\$))/"$replace"\1/"
                line=$(sed -r -e $prepare <<< "$line")

                replace=$(sed "s/\,/\|/g" <<< "$replace")
                prepare="s/(\\\$(.*[^\\]\,)?domain=(.*\|)?)\{"$domain"\}(\||\,|\$)/\\1"$replace"\\4/"
                line=$(sed -r -e $prepare <<< "$line")

                reGenerichide="(^.*)\{"$domain"\}(.*\\\$generichide\$)"

                if [[ $line =~ $reGenerichide ]]
                then
                    pre=${BASH_REMATCH[1]}
                    post=${BASH_REMATCH[2]}
                    str=$(sed "s/|/"$post"\n"$pre"/g" <<< $replace)
                    filter[$index]=$pre$str$post
                else
                    filter[$index]="$line"
                fi
            fi
        done
    done

    printf "%s\n" "${filter[@]}" > "../"$file
done

echo "Done."
exit
