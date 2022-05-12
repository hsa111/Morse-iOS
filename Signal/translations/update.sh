for dir in `find . -name "*.lproj" | awk -F\/ '{print $2}'`
do
    if [[ "$dir" != "en.lproj" ]] && [[ "$dir" != "zh_CN.lproj" ]] && [[ "$dir" != "zh_HK.lproj" ]] && [[ "$dir" != "zh_TW.lproj" ]]
    then
        echo "update $dir by english"
        cat "$dir/Localizable.strings" en.txt > /tmp/t.txt
        mv /tmp/t.txt "$dir/Localizable.strings"
    elif [[ "$dir" == "zh_HK.lproj" ]] || [[ "$dir" == "zh_TW.lproj" ]] 
    then
        echo "update $dir by chinese"
        cat "$dir/Localizable.strings" cn.txt > /tmp/t.txt
        mv /tmp/t.txt "$dir/Localizable.strings"
    fi  
done

