#!/usr/bin/env zsh
declare -A S1
declare -A S2

U1="https://api.admiralcloud.com"
U2="https://apidev.admiralcloud.com"

read -e "?Please enter URL #1 or leave empty for default [${U1}]: " input
U1="${input:-$U1}"
read -e "?Please enter URL #2 or leave empty for default [${U2}]: " input
U2="${input:-$U2}"
echo "-----------"

# SERVER 1
echo "Fetching response headers for ${U1}"
while IFS=':' read key value; do
	case "$key" in
			HTTP*) 
				;;
			etag*)
				;;
			date*)
				;;
			x-response-time*)
				;;
			*)
				if [ ${#key} -gt 2 ]; then
					# remove leading whitespace characters
					value="${value#"${value%%[![:space:]]*}"}"
					# remove trailing whitespace characters
					value="${value%"${value##*[![:space:]]}"}"
					S1[$key]=$value
					#echo "$key -> $value"
				fi
				;;
		esac
done < <(curl -sI -X GET ${U1})

# SERVER 2
echo "Fetching response headers for ${U2}"
while IFS=':' read key value; do		
	case "$key" in
			HTTP*) 
				;;
			etag*)
				;;	
			date*)
				;;
			x-response-time*)
				;;
			*)
				if [ ${#key} -gt 2 ]; then
					# remove leading whitespace characters
					value="${value#"${value%%[![:space:]]*}"}"
					# remove trailing whitespace characters
					value="${value%"${value##*[![:space:]]}"}"
					S2[$key]=$value
					#echo "$key -> $value"
				fi
				;;
		esac
done < <(curl -sI -X GET ${U2})
echo "-----------"


echo "Creating MD-style table:"
echo ""
echo "|Header|S1*|S2*|"
echo "|---|---|---|"
for identifier value in ${(kv)S1}; do
	s2v=$S2[$identifier]
	#echo $identifier
	#echo $value
	#echo $s2v
	echo "|${identifier}|${value}|${s2v}|"
done
echo ""
echo "*S1 -> ${U1}"
echo "*S2 -> ${U2}"
