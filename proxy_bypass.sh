#!/bin/bash -
#===============================================================================
#
#          FILE: proxy_bypass.sh
#
#         USAGE: ./proxy_bypass.sh
#
#   DESCRIPTION: list of functions to configure the proxy and bypass it
#
#       OPTIONS: ---
#  REQUIREMENTS: ---
#          BUGS: ---
#         NOTES: ---
#        AUTHOR: Christophe Priouzeau (), christophe.priouzeau@linaro.org
#  ORGANIZATION: STMicroelectronics
#       CREATED: 03/13/2014 02:25:28 PM CET
#      REVISION:  ---
#===============================================================================

#
# ---------------------------------------------
#              proxy ST
# ---------------------------------------------
#
#LOCAL_PROXY_HOST=172.29.52.166
LOCAL_PROXY_HOST=appgw.gnb.st.com
#LOCAL_PROXY_PORT=80
LOCAL_PROXY_PORT=8080
LOCAL_NO_PROXY=.st.com
STFORGE_NO_PROXY=.stforge.com
#
# overide proxy parameters
#
if [ ! -z $FORCE_PROXY_HOST ];
then
    LOCAL_PROXY_HOST=$FORCE_PROXY_HOST
fi
if [ ! -z $FORCE_PROXY_PORT ];
then
    LOCAL_PROXY_PORT=$FORCE_PROXY_PORT
fi
if [ ! -z $FORCE_NO_PROXY ];
then
    LOCAL_NO_PROXY=$FORCE_NO_PROXY
fi

PROXY_CREDENTIAL_FILE="$HOME/.git-proxy/.git_corkscrew_auth"


#-------------------------------------------------
# corkscrew
# ------------------------------------------------
#
# init corkscrew file
# $HOME/.git-proxy/git-proxy-corkscrew.sh
# $HOME/.git-proxy/git_corkscrew_auth
_proxy_init_corkscrew()
{
    #install corkscrew
    command -v corkscrew > /dev/null 2>&1 || {	echo -e >&2 "Require 'corkscrew'\nInstalling...\n"; sudo apt-get install corkscrew;}

    # Init corkscrew full path
    CORKSCREW_PATH=$(command -v corkscrew)

    # configure corkscrew
    mkdir -p $HOME/.git-proxy
cat > $HOME/.git-proxy/git-proxy-corkscrew.sh <<EOF
#!/bin/bash
exec $CORKSCREW_PATH $LOCAL_PROXY_HOST $LOCAL_PROXY_PORT \$* $PROXY_CREDENTIAL_FILE
EOF
    chmod +x $HOME/.git-proxy/git-proxy-corkscrew.sh
}


#
# Set password for corkscrew script
#
_proxy_set_password_corkscrew()
{
    echo -n "$LOCAL_PROXY_USERNAME:$LOCAL_PROXY_PASSWORD" > $PROXY_CREDENTIAL_FILE
    chmod 600 $PROXY_CREDENTIAL_FILE
    chmod +x $HOME/.git-proxy/git-proxy-corkscrew.sh
}


#
# Update proxy host and port for corkscrew script
#
_proxy_host_update_corkscrew()
{
    if [[ -f $HOME/.git-proxy/git-proxy-corkscrew.sh ]];
    then
        # Init corkscrew full path
        CORKSCREW_PATH=$(command -v corkscrew)
        # Get current corkscrew_path set in script
        current_corkscrew_path=`grep "^exec $CORKSCREW_PATH " $HOME/.git-proxy/git-proxy-corkscrew.sh | sed "s|^exec \(.*corkscrew\) .*$|\1|g"`
        if ! [ "$current_corkscrew_path" == "$CORKSCREW_PATH" ];
        then
            sed -i "s|^exec .*corkscrew \(.*\)$|exec $CORKSCREW_PATH \1|g" $HOME/.git-proxy/git-proxy-corkscrew.sh
        fi
        # Get current proxy_host set in script
        current_proxy_host=`grep "exec $CORKSCREW_PATH" $HOME/.git-proxy/git-proxy-corkscrew.sh | sed "s|^exec .*corkscrew \([^ ]*\) [^ ]* \(.*\)$|\1|g"`
        if ! [ "$current_proxy_host" == "$LOCAL_PROXY_HOST" ];
        then
            sed -i "s|^exec $CORKSCREW_PATH [^ ]* [^ ]* \(.*\)$|exec $CORKSCREW_PATH $LOCAL_PROXY_HOST $LOCAL_PROXY_PORT \1|g" $HOME/.git-proxy/git-proxy-corkscrew.sh
        fi
    else
        echo "[WARNING]: proxy host not updated: .git-proxy/git-proxy-corkscrew.sh file not found."
    fi
}


#
# enable
#
#
_proxy_enable_corkscrew()
{
    git config --global --unset-all core.gitproxy $HOME/.git-proxy/git-proxy-corkscrew.sh
    # use corkscrew as git proxy
    git config --global --add core.gitproxy $HOME/.git-proxy/git-proxy-corkscrew.sh
}
#
# Disable
#
#
_proxy_disable_corkscrew()
{
    git config --global --unset-all core.gitproxy $HOME/.git-proxy/git-proxy-corkscrew.sh
}


#-------------------------------------------------
# svn
# ------------------------------------------------
# init svn
# $HOME/.subversion/servers
_proxy_init_svn()
{
    if [[ ! -f $HOME/.subversion/servers ]];
    then
        mkdir -p $HOME/.subversion
        echo "[groups]" > $HOME/.subversion/servers

        echo "[global]" >> $HOME/.subversion/servers
        echo "# http-proxy-host = defaultproxy.whatever.com" >> $HOME/.subversion/servers
        echo "# http-proxy-port = 7000" >> $HOME/.subversion/servers
        echo "http-proxy-exceptions = *$LOCAL_NO_PROXY " >> $HOME/.subversion/servers
        echo "store-passwords = yes" >> $HOME/.subversion/servers
        echo "store-plaintext-passwords = yes" >> $HOME/.subversion/servers
    fi
    proxy_set=`cat $HOME/.subversion/servers | grep '^http-proxy-host' | wc -l `
    if [[ $proxy_set -eq 0 ]];
    then
        echo "#new configuration: " >> $HOME/.subversion/servers
        echo "http-proxy-host = $LOCAL_PROXY_HOST" >> $HOME/.subversion/servers
        echo "http-proxy-port = $LOCAL_PROXY_PORT" >> $HOME/.subversion/servers
    fi

    # BUG: when you launch SVN a new server is created, so need to create a backup of new config
    if [[ -f $HOME/.subversion/servers.bak ]];
    then
        echo "[WARNING]: .subversion/servers.bak already exists. Can't backup new config."
    else
        cp $HOME/.subversion/servers $HOME/.subversion/servers.bak
    fi
}


#
# set password for http proxy
#
_proxy_set_password_svn()
{
    if [[ -f $HOME/.subversion/servers ]];
    then
        proxy_user_set=$(cat $HOME/.subversion/servers | grep '^http-proxy-username' | wc -l)
        if [[ "$proxy_user_set" -gt 0 ]];
        then
            # Remove any previous http entries for username and password
            sed -i '/^http-proxy-username =.*/d' $HOME/.subversion/servers
            sed -i '/^http-proxy-password =.*/d' $HOME/.subversion/servers
        fi
        echo "http-proxy-username = $LOCAL_PROXY_USERNAME" >> $HOME/.subversion/servers
        echo "http-proxy-password = $LOCAL_PROXY_PASSWORD" >> $HOME/.subversion/servers
        chmod 600 $HOME/.subversion/servers
    fi
}


#
# Update proxy host and port for svn
#
_proxy_host_update_svn()
{
    if [[ -f $HOME/.subversion/servers ]];
    then
        proxy_set=`grep '^http-proxy-host' $HOME/.subversion/servers | wc -l `
        if [[ $proxy_set -ge 1 ]];
        then
            host_set=`grep '^http-proxy-host' $HOME/.subversion/servers | sed "s|^http-proxy-host =\(.*$\)|\1|g"`
            if ! [ "$host_set" == "$LOCAL_PROXY_HOST" ];
            then
                LOCAL_DATE=`date '+%Y_%m_%d-%02k_%M'`
                echo "[WARNING]: .subversion/servers is backuped on .subversion/servers.$LOCAL_DATE"
                cp -f $HOME/.subversion/servers $HOME/.subversion/servers.$LOCAL_DATE
                sed -i "s|^http-proxy-host =.*$|http-proxy-host = $LOCAL_PROXY_HOST|g" $HOME/.subversion/servers
                sed -i "s|^http-proxy-port =.*$|http-proxy-port = $LOCAL_PROXY_PORT|g" $HOME/.subversion/servers
            fi
        fi
    else
        echo "[WARNING]: proxy host not updated: .subversion/servers file not found."
    fi
}


#
# enable
#
#
_proxy_enable_svn()
{
    if [[ -f $HOME/.subversion/servers ]];
    then
        # Nothing to do for $HOME/.subversion/servers
        # BUG: when you launch SVN a new server was created.
        LOCAL_DATE=`date '+%Y_%m_%d-%02k_%M'`
        echo "[WARNING]: .subversion/servers is backuped on .subversion/servers.$LOCAL_DATE"
        mv $HOME/.subversion/servers $HOME/.subversion/servers.$LOCAL_DATE
        if [[ -f $HOME/.subversion/servers.bak ]];
        then
            cp $HOME/.subversion/servers.bak $HOME/.subversion/servers
        fi
    else
        if [[ -f $HOME/.subversion/servers.bak ]];
        then
            cp $HOME/.subversion/servers.bak $HOME/.subversion/servers
        fi
    fi
}
#
# Disable
#
#
_proxy_disable_svn()
{
    if [[ -f $HOME/.subversion/servers ]];
    then
        echo "Move .subversion/servers on .subversion/servers.bak"
        mv -f $HOME/.subversion/servers $HOME/.subversion/servers.bak
    fi
}


#-------------------------------------------------
# Bash session
# ------------------------------------------------
# init
_proxy_init_env()
{
    _uri=$LOCAL_PROXY_HOST:$LOCAL_PROXY_PORT
    if [ `grep '^#export http_proxy=*' $HOME/.bashrc | grep @$_uri | wc -l` -ge 1 ] || [ `grep '^export http_proxy=*' $HOME/.bashrc | grep @$_uri | wc -l` -ge 1 ];
    then
        echo "The proxy variable was already defined on your bashrc"
    else
        echo "" >> $HOME/.bashrc
        echo "#Proxy by pass variable"  >> $HOME/.bashrc
        echo "export http_proxy=http://${LOCAL_PROXY_USERNAME// /%20}:\$(sed 's,^[^:]*:,,' $PROXY_CREDENTIAL_FILE | od -A n -t x1 -w128 | tr ' ' '%' | sed 's,%0a$,,')@$LOCAL_PROXY_HOST:$LOCAL_PROXY_PORT"  >> $HOME/.bashrc
        echo "export https_proxy=http://${LOCAL_PROXY_USERNAME// /%20}:\$(sed 's,^[^:]*:,,' $PROXY_CREDENTIAL_FILE | od -A n -t x1 -w128 | tr ' ' '%' | sed 's,%0a$,,')@$LOCAL_PROXY_HOST:$LOCAL_PROXY_PORT"  >> $HOME/.bashrc
        echo "export ftp_proxy=http://${LOCAL_PROXY_USERNAME// /%20}:\$(sed 's,^[^:]*:,,' $PROXY_CREDENTIAL_FILE | od -A n -t x1 -w128 | tr ' ' '%' | sed 's,%0a$,,')@$LOCAL_PROXY_HOST:$LOCAL_PROXY_PORT"  >> $HOME/.bashrc
        echo "export no_proxy='$LOCAL_NO_PROXY,$STFORGE_NO_PROXY'"  >> $HOME/.bashrc
        chmod 600 $HOME/.bashrc
    fi

    return 0
}


#
# Set password for Bash session
#
_proxy_set_password_env()
{
    echo "SET bash proxy"
    export http_proxy=http://${LOCAL_PROXY_USERNAME// /%20}:$LOCAL_PROXY_PASSWORD_HEXA@$LOCAL_PROXY_HOST:$LOCAL_PROXY_PORT
    export https_proxy=http://${LOCAL_PROXY_USERNAME// /%20}:$LOCAL_PROXY_PASSWORD_HEXA@$LOCAL_PROXY_HOST:$LOCAL_PROXY_PORT
    export ftp_proxy=http://${LOCAL_PROXY_USERNAME// /%20}:$LOCAL_PROXY_PASSWORD_HEXA@$LOCAL_PROXY_HOST:$LOCAL_PROXY_PORT
    export no_proxy=$LOCAL_NO_PROXY,$STFORGE_NO_PROXY
    if [ `grep '^export http_proxy=*' $HOME/.bashrc | wc -l` -eq 1 ];
    then
        echo "Update http_proxy, https_proxy and ftp_proxy in .bashrc"
        sed -i "s,export http_proxy=.*,export http_proxy=http://${LOCAL_PROXY_USERNAME// /%20}:\$(sed 's\,^[^:]*:\,\,' $PROXY_CREDENTIAL_FILE | od -A n -t x1 -w128 | tr ' ' '%' | sed 's\,%0a$\,\,')@$LOCAL_PROXY_HOST:$LOCAL_PROXY_PORT,g" $HOME/.bashrc
        sed -i "s,export https_proxy=.*,export https_proxy=http://${LOCAL_PROXY_USERNAME// /%20}:\$(sed 's\,^[^:]*:\,\,' $PROXY_CREDENTIAL_FILE | od -A n -t x1 -w128 | tr ' ' '%' | sed 's\,%0a$\,\,')@$LOCAL_PROXY_HOST:$LOCAL_PROXY_PORT,g" $HOME/.bashrc
        sed -i "s,export ftp_proxy=.*,export ftp_proxy=http://${LOCAL_PROXY_USERNAME// /%20}:\$(sed 's\,^[^:]*:\,\,' $PROXY_CREDENTIAL_FILE | od -A n -t x1 -w128 | tr ' ' '%' | sed 's\,%0a$\,\,')@$LOCAL_PROXY_HOST:$LOCAL_PROXY_PORT,g" $HOME/.bashrc
    fi
}


#
# Update proxy host and port in bashrc file if needed
#
_proxy_host_update_env()
{
    target="http_proxy https_proxy ftp_proxy"
    for s in $target
    do
        if [ `grep '^#export '$s'=*' $HOME/.bashrc | wc -l` -ge 1 ] || [ `grep '^export '$s'=*' $HOME/.bashrc | wc -l` -ge 1 ];
        then
            echo "Update $s in .bashrc"
            sed -i "s,export $s=\([^@]*\)@[^:]*:.*$,export $s=\1@$LOCAL_PROXY_HOST:$LOCAL_PROXY_PORT,g" $HOME/.bashrc
        fi
    done
}


#
# enable
#
#
_proxy_enable_env()
{
    _uri=$LOCAL_PROXY_HOST:$LOCAL_PROXY_PORT
    if [ `grep '^#export http_proxy=*' $HOME/.bashrc | grep @$_uri | wc -l` -eq 1 ];
    then
        sed -i "s,#export http_proxy=\([^@]*\)@$LOCAL_PROXY_HOST:$LOCAL_PROXY_PORT,export http_proxy=\1@$LOCAL_PROXY_HOST:$LOCAL_PROXY_PORT,g" $HOME/.bashrc
        sed -i "s,#export https_proxy=\([^@]*\)@$LOCAL_PROXY_HOST:$LOCAL_PROXY_PORT,export https_proxy=\1@$LOCAL_PROXY_HOST:$LOCAL_PROXY_PORT,g" $HOME/.bashrc
        sed -i "s,#export ftp_proxy=\([^@]*\)@$LOCAL_PROXY_HOST:$LOCAL_PROXY_PORT,export ftp_proxy=\1@$LOCAL_PROXY_HOST:$LOCAL_PROXY_PORT,g" $HOME/.bashrc
    fi
    unset _uri
    return 0
}
#
# Disable
#
#
_proxy_disable_env()
{
    if [ `grep '^export http_proxy=*' $HOME/.bashrc | grep @$LOCAL_PROXY_HOST:$LOCAL_PROXY_PORT | wc -l` -eq 1 ];
    then
        sed -i "s,export http_proxy=\([^@]*\)@$LOCAL_PROXY_HOST:$LOCAL_PROXY_PORT,#export http_proxy=\1@$LOCAL_PROXY_HOST:$LOCAL_PROXY_PORT,g" $HOME/.bashrc
        sed -i "s,export https_proxy=\([^@]*\)@$LOCAL_PROXY_HOST:$LOCAL_PROXY_PORT,#export https_proxy=\1@$LOCAL_PROXY_HOST:$LOCAL_PROXY_PORT,g" $HOME/.bashrc
        sed -i "s,export ftp_proxy=\([^@]*\)@$LOCAL_PROXY_HOST:$LOCAL_PROXY_PORT,#export ftp_proxy=\1@$LOCAL_PROXY_HOST:$LOCAL_PROXY_PORT,g" $HOME/.bashrc
    fi
    unset http_proxy
    unset https_proxy
    unset ftp_proxy
    unset no_proxy
}


#-------------------------------------------------
# ssh
#------------------------------------------------
_proxy_host_update_ssh()
{
    if [  -f $HOME/.ssh/config ];
    then
        uniq_proxy=`grep "ProxyCommand corkscrew" $HOME/.ssh/config | sed "s|^.*ProxyCommand corkscrew \([^ ]*\) [^ ]* .*$|\1|g" | sort -u | wc -l`
        if [ $uniq_proxy -eq 1 ];
        then
            current_proxy_host=`grep "ProxyCommand corkscrew" $HOME/.ssh/config | sed "s|^.*ProxyCommand corkscrew \([^ ]*\) [^ ]* .*$|\1|g" | sort -u`
            if ! [ "$current_proxy_host" == "$LOCAL_PROXY_HOST" ];
            then
                LOCAL_DATE=`date '+%Y_%m_%d-%02k_%M'`
                echo "[WARNING]: .ssh/config is backuped on .ssh/config.$LOCAL_DATE"
                cp -f $HOME/.ssh/config $HOME/.ssh/config.$LOCAL_DATE
                sed -i "s|\(^.*\)ProxyCommand corkscrew [^ ]* [^ ]* \(.*$\)|\1ProxyCommand corkscrew $LOCAL_PROXY_HOST $LOCAL_PROXY_PORT \2|g" $HOME/.ssh/config
            fi
        else
            echo "[WARNING]: several proxy host defined in .ssh/config file: can't decide if update is required to proxy $LOCAL_PROXY_HOST"
        fi
    fi
}

_proxy_enable_ssh()
{
    if [  -f $HOME/.ssh/config ];
    then
        sed -i "s/^[\t ]*##ProxyCommand/\tProxyCommand/" $HOME/.ssh/config
    fi
}
_proxy_disable_ssh()
{
    if [  -f $HOME/.ssh/config ];
    then
        sed -i "s/^[\t ]*ProxyCommand/\t##ProxyCommand/" $HOME/.ssh/config
    fi
}

#-------------------------------------------------
# Generic
# ------------------------------------------------
proxy_init()
{
    _proxy_init_svn
    _proxy_init_corkscrew
}

proxy_set_password()
{
    if [ ! -z $LOCAL_PROXY_USERNAME ]
    then
        _proxy_set_password_svn
        _proxy_set_password_corkscrew
        _proxy_set_password_env
    fi
}
proxy_enable()
{
    _proxy_enable_svn
    _proxy_enable_corkscrew
    _proxy_enable_ssh
    _proxy_enable_env
}
proxy_disable()
{
    _proxy_disable_svn
    _proxy_disable_corkscrew
    _proxy_disable_ssh
    _proxy_disable_env
}

proxy_shell_set_password()
{
    if [ ! -z "$LOCAL_PROXY_USERNAME" ]
    then
        _proxy_set_password_env
    fi
}
proxy_shell_disable()
{
    _proxy_disable_env
}

proxy_host_update()
{
    _proxy_host_update_corkscrew
    _proxy_host_update_env
    _proxy_host_update_svn
    _proxy_host_update_ssh
}


#-------------------------------------------------
# Ask password to user
# ------------------------------------------------
_proxy_ask_password_shell()
{
    read -p "Username: " ENTRY_user
    read -s -p "Password: " ENTRY_pass
    echo ""
    echo "   Username: $ENTRY_user"
    echo "   Password: -----------"
    echo -n "Which would you like this parameters ? [Y/n]"
    read answer
    if [ -z "$answer" ];
    then
        LOCAL_PROXY_USERNAME=$ENTRY_user
        LOCAL_PROXY_PASSWORD=$ENTRY_pass
        return 0
    else
        if [ `echo -n $answer | grep -q -e "^[yY][a-zA-Z]*$" ` ];
        then
            LOCAL_PROXY_USERNAME=$ENTRY_user
            LOCAL_PROXY_PASSWORD=$ENTRY_pass
            return 0
        else
            LOCAL_PROXY_USERNAME=
            LOCAL_PROXY_PASSWORD=
            return 1
        fi
    fi
}
_proxy_ask_password_zenity()
{
    ENTRY=`zenity --forms --title="HTTP/HTTPS Proxy" --text="Local Proxy configuration" --add-entry="Username" --add-password="Password" --separator="|" `
    if [ "$?" -eq 1 ]; then
        echo "Proxy configuration canceled"
        echo "################################################"
        echo "WARNING: no proxy setted on environment variable"
        echo "################################################"
        LOCAL_PROXY_USERNAME=
        LOCAL_PROXY_PASSWORD=
        return 1
    else
        ENTRY_user=`echo $ENTRY | cut -d "|" -f1`
        ENTRY_pass=`echo $ENTRY | cut -d "|" -f2`
        LOCAL_PROXY_USERNAME=$ENTRY_user
        LOCAL_PROXY_PASSWORD=$ENTRY_pass
    fi
    return 0
}

proxy_ask_password()
{
    #echo "Please enter our HTTP/HTTPS/FTP proxy:"
    local_PROXY_SERVER=$LOCAL_PROXY_HOST:$LOCAL_PROXY_PORT
    echo " (we use $local_PROXY_SERVER as HTTP/HTTPS/FTP/SVN/GIT proxy)"

    if [ ! -z $DISPLAY ];
    then
        _proxy_ask_password_zenity
    else
        _proxy_ask_password_shell
        if [ "$?" -eq 1 ];
        then
            echo "Proxy configuration canceled"
            echo "################################################"
            echo "WARNING: no proxy setted on environment variable"
            echo "################################################"
            return 0
        fi
     fi
    local_text_password=""

    for letter in $(echo "$LOCAL_PROXY_PASSWORD" | sed "s/\(.\)/'\1 /g");do local_text_password=$local_text_password`printf '%%%x' "$letter"`;done
    echo "PASSWORD=$local_text_password ($LOCAL_PROXY_PASSWORD)"
    LOCAL_PROXY_PASSWORD_HEXA=$local_text_password
    return 1
}


#-------------------------------------------------
#  Usage
# ------------------------------------------------

usage()
{
    cat <<EOF

Usage: $PRG_NAME <command>
List of commands available:
    init: create all the files for the proxy bypass
    update: update the password for proxy
    enable: enable the proxy bypass
    disable: disable the proxy bypass
    session: put in place the proxy variable only for the local shell session
    bashrc: write the proxy variable on bashrc file

examples:

For Forcing the default value of proxy server some ENV variable are defined:
    FORCE_PROXY_HOST
    FORCE_PROXY_PORT
    FORCE_NO_PROXY
Value know by default:
    PROXY_HOST=$LOCAL_PROXY_HOST
    PROXY_PORT=$LOCAL_PROXY_PORT
    NO_PROXY=$LOCAL_NO_PROXY
ex.:
    FORCE_PROXY_HOST=<My_company_proxy_addr> $PRG_NAME init
    FORCE_PROXY_HOST=<My_company_proxy_addr> FORCE_PROXY_PORT=<My_company_proxy_port> $PRG_NAME init
    FORCE_PROXY_HOST=<My_company_proxy_addr> FORCE_PROXY_PORT=<My_company_proxy_port> FORCE_NO_PROXY=<my_comony_suffix> $PRG_NAME init
ex.:
    export FORCE_PROXY_HOST=<My_company_proxy_addr>
    export FORCE_PROXY_PORT=<My_company_proxy_port>
    export FORCE_NO_PROXY=<my_comony_suffix>
    $PRG_NAME init
ex.:
    $PRG_NAME update
    $PRG_NAME enable
    $PRG_NAME disable
    source $PRG_NAME session
ex.:
    $PRG_NAME update
    $PRG_NAME enable
    $PRG_NAME bashrc
    source $HOME/.bashrc
EOF
}

info_file() {
    cat <<EOF

    File Impacted by the script:
    - $HOME/.git-proxy/git-proxy-corkscrew.sh
    - $PROXY_CREDENTIAL_FILE
    - $HOME/.gitconfig
    - $HOME/.subversion/servers
    - $HOME/.ssh/config
EOF
}


#
# Main
#
PRG_NAME=$0
if [ $# -eq 1 ];
then
    case $1 in
    init)
        proxy_init
        proxy_enable
        proxy_ask_password
        proxy_set_password
        info_file
        ;;
    update)
        proxy_host_update
        proxy_ask_password
        proxy_set_password
        info_file
        ;;
    enable)
        proxy_enable
        info_file
        ;;
    disable)
        proxy_disable
        info_file
        ;;
    session)
        if [ $0 == "bash" ];
        then
            proxy_ask_password
            proxy_shell_set_password
        else
            echo "###################################"
            echo "ERROR: YOU MUST SOURCE the script"
            echo "###################################"
        fi
        ;;
    bashrc)
        proxy_ask_password
        _proxy_init_env
        ;;
    *)
        usage
        ;;
    esac
else
    usage
fi

unset LOCAL_PROXY_HOST LOCAL_PROXY_PORT LOCAL_NO_PROXY
unset _proxy_init_corkscrew _proxy_set_password_corkscrew _proxy_enable_corkscrew _proxy_disable_corkscrew
unset _proxy_init_svn _proxy_set_password_svn _proxy_enable_svn _proxy_disable_svn
unset _proxy_init_env _proxy_set_password_env _proxy_enable_env _proxy_disable_env
unset proxy_init proxy_set_password proxy_enable proxy_disable proxy_shell_set_password proxy_shell_disable
unset _proxy_ask_password_shell _proxy_ask_password_zenity proxy_ask_password usage
