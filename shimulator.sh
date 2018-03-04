#!/bin/sh

emulator=$ANDROID_HOME/tools/emulator
OS=$(uname -s)

function eml() {
	$emulator -list-avds | cat -n
	printf "Select AVD: "
	read index
	avd=$($emulator -list-avds | sed "${index}q;d")
	echo "$avd"
}

function start_emulator() {
	eml
	emulator -netdelay none -netspeed full -no-snapshot -no-boot-anim -no-audio -writable-system -avd $avd >/dev/null 2>&1 &
	# adb wait-for-device
	adb wait-for-device shell 'while [[ -z $(getprop sys.boot_completed) ]]; do sleep 1; done;'
}

function install_proxy() {
	if [ -z "$1" ]; then
		echo "No cert path provided by user, installing mimproxy certificate"
		cert_file="/Users/"$(whoami)"/.mitmproxy/mitmproxy-ca-cert.cer"
	else
		cert_file=$1
	fi

	# TODO check if cert exits

	echo "pushing cert into emulator"
	filename=$(openssl x509 -in $cert_file -hash -noout) # creating filename for .0 file
	echo "Certificate file name ->"$filename".0"
	openssl x509 -in $cert_file >$filename".0" # dumping content of the .cer file
	openssl x509 -in $cert_file -text -fingerprint -noout >>$filename".0"
	adb root >/dev/null 2>&1
	adb shell "mount -orw,remount /system"
	adb push $filename".0" /system/etc/security/cacerts >/dev/null 2>&1
	adb remount >/dev/null 2>&1
	rm $filename".0"
}

function start_emulator_with_proxy() {
	ip_address=$(/sbin/ifconfig | grep 'inet ' | grep -v '127.0.0.1' | cut -d: -f2 | awk '{ print $2}' | head -1)
	echo "starting emulator"
	if [ $# -lt 2 ]; then
		echo "provide a device name port number for the proxy eg. start_emulator_with_proxy Nexus5 8080"
		exit 1
	fi

	device_name=$1
	port=$2
	$ANDROID_HOME/emulator/emulator -avd $device_name -http-proxy $ip_address:$port -no-boot-anim -no-audio -writable-system >/dev/null 2>&1 &
	adb wait-for-device shell 'while [[ -z $(getprop sys.boot_completed) ]]; do sleep 1; done; input keyevent 82' && echo "success"
}

function _generate_mitm_certs() {
	if [[ ! -e mitmproxy ]]; then
		brew install mitmproxy
	fi
	mitmproxy -p _get_free_port &
	# kill by port

}

function _get_free_port() {
	BASE=1000
	INCREMENT=1
	port=$BASE
	if [[ $OS == 'linux' ]]; then
		isfree=$(netstat -tapln | grep $port)
	elif [[ $OS == 'Darwin' ]]; then
		isfree=$(lsof -nPi -sTCP:LISTEN | grep $port)
	fi

	while [[ -n "$isfree" ]]; do
		port=$((port + INCREMENT))
		isfree=$($isfree)
	done

	echo "$port"
}
