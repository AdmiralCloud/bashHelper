#!/usr/bin/env bash
# Creates key and certificate for a given domain using ECDSA P-256 as default
# Supports RSA 2048/4096 and ECDSA P-256/P-384

# Config file location
CONFIG_FILE="csr_config.conf"

# Check if config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Config file $CONFIG_FILE not found!"
    echo "Please create the config file first. See README for structure."
    exit 1
fi

# User inputs
read -p 'Enter domain: ' domain
echo "Select key type:"
echo "1) ECDSA P-256 (default)"
echo "2) ECDSA P-384"
echo "3) RSA 2048"
echo "4) RSA 4096"
read -p "Enter choice [1]: " key_choice
key_choice=${key_choice:-1}

# Set key parameters based on choice
case $key_choice in
    1)
        key_type="ecdsa-p256"
        openssl_params="ecparam -genkey -name prime256v1"
        ;;
    2)
        key_type="ecdsa-p384"
        openssl_params="ecparam -genkey -name secp384r1"
        ;;
    3)
        key_type="rsa2048"
        openssl_params="genrsa 2048"
        ;;
    4)
        key_type="rsa4096"
        openssl_params="genrsa 4096"
        ;;
    *)
        echo "Invalid choice, using ECDSA P-256"
        key_type="ecdsa-p256"
        openssl_params="ecparam -genkey -name prime256v1"
        ;;
esac

# Generate file names
date=`date +'%Y%m%d'`
key=${date}_${domain}_${key_type}.key
csr=${date}_${domain}_${key_type}.csr
config_temp=${date}_${domain}_temp.conf

# Create temporary config with domain
sed "s/DOMAIN_PLACEHOLDER/$domain/g" "$CONFIG_FILE" > "$config_temp"

echo ""
echo "Key: $key"
echo "CSR: $csr"
echo "Key type: $key_type"
echo ""

# Generate private key
echo "Generating private key..."
openssl $openssl_params -out "$key"

# Generate CSR
echo "Generating CSR..."
if openssl req -new -key "$key" -out "$csr" -config "$config_temp"; then
    echo "CSR generated successfully"
else
    echo "Error generating CSR. Check your config file values."
    rm -f "$config_temp"
    exit 1
fi

# Clean up temporary config
rm "$config_temp"

# Check if CSR was actually created
if [ ! -f "$csr" ]; then
    echo "CSR file was not created. Exiting."
    exit 1
fi

echo ""
echo "Files created successfully:"
echo "Private key: $key"
echo "CSR: $csr"

# Verify CSR
echo ""
echo "Verifying CSR..."
echo "========================"

# Extract CSR details
csr_subject=$(openssl req -in "$csr" -noout -subject | sed 's/subject=//')
csr_key_info=$(openssl req -in "$csr" -noout -text | grep -A 3 "Public Key Algorithm")

# Extract individual values from CSR subject
csr_country=$(echo "$csr_subject" | grep -o 'C=[^,]*' | cut -d'=' -f2)
csr_state=$(echo "$csr_subject" | grep -o 'ST=[^,]*' | cut -d'=' -f2)
csr_city=$(echo "$csr_subject" | grep -o 'L=[^,]*' | cut -d'=' -f2)
csr_org=$(echo "$csr_subject" | grep -o 'O=[^,]*' | cut -d'=' -f2)
csr_ou=$(echo "$csr_subject" | grep -o 'OU=[^,]*' | cut -d'=' -f2)
csr_cn=$(echo "$csr_subject" | grep -o 'CN=[^,]*' | cut -d'=' -f2)

# Extract expected values from config
expected_domain="$domain"
expected_country=$(grep "^C = " "$CONFIG_FILE" | cut -d'=' -f2 | sed 's/^ *//' | sed 's/ *$//')
expected_state=$(grep "^ST = " "$CONFIG_FILE" | cut -d'=' -f2 | sed 's/^ *//' | sed 's/ *$//')
expected_city=$(grep "^L = " "$CONFIG_FILE" | cut -d'=' -f2 | sed 's/^ *//' | sed 's/ *$//')
expected_org=$(grep "^O = " "$CONFIG_FILE" | cut -d'=' -f2 | sed 's/^ *//' | sed 's/ *$//')
expected_ou=$(grep "^OU = " "$CONFIG_FILE" | cut -d'=' -f2 | sed 's/^ *//' | sed 's/ *$//')

# Create verification table
echo ""
printf "%-20s | %-30s | %-30s | %s\n" "Field" "Config Value" "CSR Value" "Status"
echo "--------------------------------------------------------------------------------"

# Country
if [ "$expected_country" = "$csr_country" ]; then
    status="✓"
else
    status="✗"
fi
printf "%-20s | %-30s | %-30s | %s\n" "Country (C)" "$expected_country" "$csr_country" "$status"

# State
if [ "$expected_state" = "$csr_state" ]; then
    status="✓"
else
    status="✗"
fi
printf "%-20s | %-30s | %-30s | %s\n" "State (ST)" "$expected_state" "$csr_state" "$status"

# City
if [ "$expected_city" = "$csr_city" ]; then
    status="✓"
else
    status="✗"
fi
printf "%-20s | %-30s | %-30s | %s\n" "City (L)" "$expected_city" "$csr_city" "$status"

# Organization
if [ "$expected_org" = "$csr_org" ]; then
    status="✓"
else
    status="✗"
fi
printf "%-20s | %-30s | %-30s | %s\n" "Organization (O)" "$expected_org" "$csr_org" "$status"

# Organizational Unit
if [ "$expected_ou" = "$csr_ou" ]; then
    status="✓"
else
    status="✗"
fi
printf "%-20s | %-30s | %-30s | %s\n" "Org Unit (OU)" "$expected_ou" "$csr_ou" "$status"

# Domain
if [ "$expected_domain" = "$csr_cn" ]; then
    status="✓"
else
    status="✗"
fi
printf "%-20s | %-30s | %-30s | %s\n" "Domain (CN)" "$expected_domain" "$csr_cn" "$status"

echo ""
echo "Key type verification:"
case $key_choice in
    1|"")
        if echo "$csr_key_info" | grep -q "prime256v1\|256 bit"; then
            echo "✓ ECDSA P-256 key confirmed"
        else
            echo "✗ Expected ECDSA P-256 key"
        fi
        ;;
    2)
        if echo "$csr_key_info" | grep -q "secp384r1\|384 bit"; then
            echo "✓ ECDSA P-384 key confirmed"
        else
            echo "✗ Expected ECDSA P-384 key"
        fi
        ;;
    3)
        if echo "$csr_key_info" | grep -q "2048 bit"; then
            echo "✓ RSA 2048 key confirmed"
        else
            echo "✗ Expected RSA 2048 key"
        fi
        ;;
    4)
        if echo "$csr_key_info" | grep -q "4096 bit"; then
            echo "✓ RSA 4096 key confirmed"
        else
            echo "✗ Expected RSA 4096 key"
        fi
        ;;
esac

# Create ZIP file for email transfer
zip_file=${date}_${domain}_${key_type}_csr.zip
echo ""
echo "Creating ZIP file for email transfer..."
/usr/bin/zip -j "$zip_file" "$csr"

if [ $? -eq 0 ]; then
    echo "✓ ZIP file created: $zip_file"
    echo ""
    echo "Files ready:"
    echo "- Private key: $key (keep secure!)"
    echo "- CSR ZIP for email: $zip_file"
else
    echo "✗ Failed to create ZIP file"
    echo "Individual files available:"
    echo "- Private key: $key"
    echo "- CSR: $csr"
fi