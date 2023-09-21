#!/bin/bash

#variable
dir_pem="/etc/pki/entitlement"
dir_user="/home/ec2-user"
user_rhel="walkerpig@gmail.com"
pass_rhel="Baonhi30102020"
pass_key="cuongpt123"

#function
unregister_subscription() {
    sudo subscription-manager unregister
    result=$?  # Capture the exit status of the last command

    if [ $result -eq 0 ]; then
        echo "Unregistration successful."
        return 0  # Return 0 if successful
    else
        echo "Unregistration failed."
        return 1  # Return 1 if failed
    fi
}
register_subscription() {
    sudo subscription-manager register --username $1 --password $2
    result=$?  # Capture the exit status of the last command

    if [ $result -eq 0 ]; then
        echo "registration successful."
        return 0  # Return 0 if successful
    else
        echo "registration failed."
        return 1  # Return 1 if failed
    fi
}
delete_allfile() {
    sudo rm -rf $1
    result=$?  # Capture the exit status of the last command

    if [ $result -eq 0 ]; then
        echo "delete successful."
        return 0  # Return 0 if successful
    else
        echo "delete failed."
        return 1  # Return 1 if failed
    fi
}
gen_p12() {
    sudo openssl pkcs12 -export -in $dir_pem/$1 -inkey $dir_pem/$2 -name certificate_and_key -out $dir_pem/certificate_and_key.p12 -passout pass:"$pass_key"

    #check if has certificate_and_key.p12 gen file rhel.p12
    if [ -f "$dir_pem/certificate_and_key.p12" ]; then
        echo "oke"
	sudo keytool -importkeystore -srckeystore $dir_pem/certificate_and_key.p12 -srcstoretype PKCS12 -srcstorepass "$pass_key" -deststorepass "$pass_key" -destkeystore $dir_pem/keystore.p12 -deststoretype PKCS12
	result=$?  # Capture the exit status of the last command
    else
        echo "certificate_and_key.p12 not found"
	exit 1
    fi
    
    if [ $result -eq 0 ]; then
        echo "create file p12 successful."
        # gen base64 file
        sudo openssl base64 -in $dir_pem/keystore.p12 | tr -d '\n' > $dir_user/rhel_base64.txt
        return 0  # Return 0 if successful
    else
        echo "create file p12 failed."
        return 1  # Return 1 if failed
    fi
}


#register_subscription "$user_rhel" "$pass_rhel"
#return_value=$?
#echo $return_value
#exit 1

pem_files=$(find $dir_pem -maxdepth 1 -type f -name '*.pem' ! -name '*-key.pem')

# 1: System has not been subscription
if [ -z "$pem_files" ]; then
    echo "No .pem files found in the directory."
    # command 4 test
    delete_allfile "$dir_pem/*"
    # command 4 test
    register_subscription "$user_rhel" "$pass_rhel"
    
    # Loop through the .pem files and extract file names without the .pem extension
    pem_files=$(find $dir_pem -maxdepth 1 -type f -name '*.pem' ! -name '*-key.pem')
    for pem_file in $pem_files; do
        pem_name=$(basename "$pem_file" .pem)
        key_file="$pem_name-key.pem"
        echo "pem_file: $(basename "$pem_file")"
        echo "key_file: $(basename "$key_file")"
        curl_command="curl --cert $pem_files --key "$dir_pem/$key_file" https://cdn.redhat.com/content/dist/rhel9/9/x86_64/baseos/os/repodata/repomd.xml -k -w \"%{http_code}\\n\" -o /dev/null"
        echo $curl_command
        http_status=$(eval $curl_command)
        # Print test
        echo "HTTP Status Code: $http_status"
        if [ "$http_status" -eq 200 ]; then
            echo "oke"
            # regenerate the PEM file
            gen_p12 "$pem_name.pem" "$key_file"
        else
            echo "Undefined exception error, please regenerate the PEM file"
        fi
    done
    exit 1
fi

# 2 Pem file can not connect cdn redhat
for pem_file in $pem_files; do
    pem_name=$(basename "$pem_file" .pem)
    key_file="$pem_name-key.pem"

    echo "pem_file: $(basename "$pem_file")"
    echo "key_file: $(basename "$key_file")"

    curl_command="curl --cert $pem_files --key "$dir_pem/$key_file" https://cdn.redhat.com/content/dist/rhel9/9/x86_64/baseos/os/repodata/repomd.xml -k -w \"%{http_code}\\n\" -o /dev/null"

    echo $curl_command

    http_status=$(eval $curl_command)
    http_status="403"
    # Print test
    echo "HTTP Status Code: $http_status"

    if [ "$http_status" -eq 403 ]; then
        # command 4 test
        unregister_subscription
        echo "unregister_subscription"
        # command 4 test
        delete_allfile "$dir_pem/*"
        echo "delete_allfile"
        # command 4 test
        register_subscription "$user_rhel" "$pass_rhel"
        echo "register_subscription"
        echo "gen p12 file with new key"
        pem_files=$(find $dir_pem -maxdepth 1 -type f -name '*.pem' ! -name '*-key.pem')
        for pem_file in $pem_files; do
            pem_name=$(basename "$pem_file" .pem)
            key_file="$pem_name-key.pem"
            echo "pem_file: $(basename "$pem_file")"
            echo "key_file: $(basename "$key_file")"
            curl_command="curl --cert $pem_files --key "$dir_pem/$key_file" https://cdn.redhat.com/content/dist/rhel9/9/x86_64/baseos/os/repodata/repomd.xml -k -w \"%{http_code}\\n\" -o /dev/null"
            echo $curl_command
            http_status=$(eval $curl_command)
            # Print test
            echo "HTTP Status Code: $http_status"
            if [ "$http_status" -eq 200 ]; then
                echo "oke"
                # regenerate the PEM file
                gen_p12 "$pem_name.pem" "$key_file"
            else
                echo "Undefined exception error, please regenerate the PEM file"
            fi
        done
        exit 1
    elif [[ "$http_status" -eq 200 ]]; then
        #statements
        echo "oke"
    else
	    echo "Undefined exception error"
    fi
done