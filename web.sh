#!/bin/bash
# If wordlist files not found, download them
if [ ! -f ~/wordlists/subdomains.txt ]; then
    wget -P ~/wordlists http://ffuf.me/wordlist/subdomains.txt
fi

if [ ! -f ~/wordlists/common.txt ]; then
    wget -P ~/wordlists http://ffuf.me/wordlist/common.txt
fi

clear

echo -e "\e[31m _    _  ____  ____ \e[0m \e[34m  ____  _  _  ____  ____  __   \e[0m"
echo -e "\e[31m( \/\/ )( ___)(  _ \ \e[0m \e[34m(_  _)( \( )(_  _)( ___)(  )  \e[0m"
echo -e "\e[31m )    (  )__)  ) _ <\e[0m \e[34m  _)(_  )  (   )(   )__)  )(__ \e[0m"
echo -e "\e[31m(__/\__)(____)(____/\e[0m \e[34m (____)(_)\_) (__) (____)(____)\e[0m"
sleep 1
echo ""
echo ""

copied_content=$(xclip -o -selection clipboard)
# Prompt for URL
if [[ $copied_content == "http"* ]]; then
  target=$copied_content
else
  echo -e "\e[31mEnter a URL\e[0m"
  read target
fi
echo ""

# Tidy up URL
while true; do
  if [[ $target == http://* ]]; then
    target="${target#http://}"
    protocol="http://"
    break
  elif [[ $target == https://* ]]; then
    target="${target#https://}"
    protocol="https://"
    break
  elif [[ $target == *".txt" ]]; then
    if [[ -e "$target" ]]; then
      echo "File Analyzed"
    else
      echo "File not found"
      exit
    fi
    break
  else
    echo "HTTP or HTTPS?"
    read protocol
    if [[ $protocol = "http" ]]; then
      protocol="http://"
      break
    elif [[ $protocol = "https" ]]; then
      protocol="https://"
      break
    fi
  fi
done
url=$protocol$target

if [[ $target == */ ]]; then
  target="${target%/}"
fi

trimmed_url="${target#www.}"
filename="${trimmed_url%%.*}"

echo -e "Your target is: \e[36m$protocol$target\e[0m"
sleep 2

# Prompt for option
echo -e "\e[31mChoose your options:\e[0m \e[34mdirectories\e[0m | \e[35msubdomain\e[0m | \e[33msourcecode\e[0m | \e[36mvulns\e[0m"
read -a choices
echo ""

for choice in ${choices[@]};
do
  if [[ $choice == *"dir"* ]]; then
    choice="directories"
  elif [[ $choice == *"sub"* ]]; then
    choice="subdomains"
  elif [[ $choice == *"sou"* ]]; then
    choice="source"
  elif [[ $choice == *"vul"* ]]; then
    choice="vuln"
  else
    echo "bad option"
  fi
  case $choice in
  directories)
    http_status=$(curl -s -o /dev/null -w "%{http_code}" "$protocol$target")
    # Check if website needs authorized access
    if [[ "$http_status" == "401" ]] || [[ "$http_status" == "403" ]]; then
      echo -e "\e[31mYou are unauthorized\e[0m"
      username=$(zenity --entry --text "What is the username?" --title "Set Username" 2>/dev/null)
      password=$(zenity --entry --text "What is the password?" --title "Set Password" 2>/dev/null)
      auth="-U $username:$password"
    else
      auth=""
    fi

    if [[ $copied_content != "http"* ]]; then
      echo "Choose a mode (default is no mode)"
      echo -e "\e[31m-q\e[0m | \e[35m--deep-recursive\e[0m | \e[33m--delay=<seconds>\e[0m"
      read mode
      if [[ $mode != "-"* ]]; then
        mode=""
      fi
    fi
    echo ""

    echo -e "\e[31mInitializing Dirsearch\e[0m"

    # Run dirsearch
    dirsearch -u $protocol$target -x 401,404 --crawl $auth $mode
    ;;
  subdomains)

    http_status=$(curl -s -o /dev/null -w "%{http_code}" "$protocol$target")
    # Check if website needs authorized access
    if [[ "$http_status" == "401" ]] || [[ "$http_status" == "403" ]]; then
      echo -e "\e[31mYou are unauthorized\e[0m"
      username=$(zenity --entry --text "What is the username?" --title "Set Username" 2>/dev/null)
      password=$(zenity --entry --text "What is the password?" --title "Set Password" 2>/dev/null)
      login="$username:$password@"
    else
      login=""
    fi

    echo "Choose a mode (default is no mode)"
    echo -e "\e[31m-s\e[0m | \e[35m-v\e[0m | \e[33m-fw\e[0m"
    read mode
    if [[ $mode != "-v" ]] && [[ $mode != "-fw" ]] && [[ $mode != "-s" ]]; then
      mode=""
    fi
    echo ""
    echo -e "\e[31mInitializing Fuzz\e[0m"
    if [[ $mode = "-s" ]]; then
      echo ""
      echo -e "\e[31m     /'___\  /'___\           /'___\  \e[0m"
      echo -e "\e[31m    /\ \__/ /\ \__/  __  __  /\ \__/  \e[0m"
      echo -e "\e[31m    \ \ ,__\\ \ ,__\/\ \/\ \ \ \ ,__\ \e[0m"
      echo -e "\e[31m     \ \ \_/ \ \ \_/\ \ \_\ \ \ \ \_/ \e[0m"
      echo -e "\e[31m      \ \_\   \ \_\  \ \____/  \ \_\  \e[0m"
      echo -e "\e[31m       \/_/    \/_/   \/___/    \/_/  \e[0m"
      echo ""
    fi

    target="${target#www.}"

    # Run ffuf
    ffuf -u $protocol$login"FUZZ."$target $mode -w ~/wordlists/subdomains.txt -mc 100-399,500-599 | tee ~/Desktop/"$filename subdomains.txt"
    target="www."$target
    ;;
  source)
    echo "what information do you want to see?"
    echo "source | request | all"
    read choiceinfo
    if [[ $choiceinfo = *"sou"* ]]; then
      curl $url
    elif [[ $choiceinfo = *"req"* ]]; then
      curl -I $url
    else
      curl $url
      curl -I $url
    fi
    ;;
  vuln)
    if [[ ! $target = *".txt" ]] && [[ ! $target = "http"* ]] && [[ ! $target = "https"*  ]]; then
      echo -e "\e[31mInput .txt file location\e[0m"
      read target
    fi

    ;;
  esac
done

