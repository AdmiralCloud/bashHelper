# Specify the current and new certificate ARNs as well as the profile
PROFILE=default.mfa
SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
if test -f "${SCRIPTPATH}/config.txt"; then
  source $SCRIPTPATH/config.txt
fi

# PROFILE
read -e -p "Please enter your profile or leave empty for default [${PROFILE}]: " input
PROFILE="${input:-$PROFILE}"

# ARN of certificates
read -e -p "Current certificate ARN [${CURRENT_CERTIFICATE_ARN}]: " input
CURRENT_CERTIFICATE_ARN="${input:-$CURRENT_CERTIFICATE_ARN}"

read -e -p "New certificate ARN [${NEW_CERTIFICATE_ARN}]: " input
NEW_CERTIFICATE_ARN="${input:-$NEW_CERTIFICATE_ARN}"

# Get a list of all CloudFront distributions
distributions=$(aws cloudfront list-distributions --query 'DistributionList.Items[].{Id: Id, CNAMEs: Aliases.Items[], CertificateArn: ViewerCertificate.ACMCertificateArn}' --output json  --profile $PROFILE)

# Loop through each distribution
for distribution in $(echo "${distributions}" | jq -r '.[] | @base64'); do
    # Parse distribution details
    _jq() {
        echo ${distribution} | base64 --decode | jq -r ${1}
    }
    distribution_id=$(_jq '.Id')
    cnames=($(_jq '.CNAMEs'))
    current_certificate_arn=$(_jq '.CertificateArn')

    # Check if the distribution uses the current certificate ARN
    if [[ "${current_certificate_arn}" == "${CURRENT_CERTIFICATE_ARN}" ]]; then
        echo "Distribution ID: ${distribution_id}"
        echo "CNAMEs: ${cnames[@]}"
        echo "Current Certificate ARN: ${current_certificate_arn}"

        # Update the distribution with the new certificate ARN if necessary
        if [[ "${current_certificate_arn}" != "${NEW_CERTIFICATE_ARN}" ]]; then
            echo "Updating certificate for the distribution..."
            distribution_config=$(aws cloudfront get-distribution-config --id "${distribution_id}" --query 'DistributionConfig' --profile $PROFILE)
            updated_config=$(echo "${distribution_config}" | jq --arg cert_arn "${NEW_CERTIFICATE_ARN}" '.ViewerCertificate.ACMCertificateArn = $cert_arn')
            aws cloudfront update-distribution --id "${distribution_id}" --if-match "$(aws cloudfront get-distribution-config --id "${distribution_id}" --query 'ETag' --output text --profile $PROFILE)" --distribution-config "${updated_config}" --profile $PROFILE
            echo "Certificate updated successfully!"
        else
            echo "Certificate is already up to date."
        fi
    fi
done