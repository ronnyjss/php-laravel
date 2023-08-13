#!/usr/bin/env bash

if [[ $XDEBUG_ENABLED == true ]]; then
    # Ativa a extensão xdebug
    sed -i "s/;zend_extension=xdebug.so/zend_extension=xdebug.so/g" /usr/local/etc/php/conf.d/xdebug.ini

    # Ativa a configuração remota xdebug
    if [[ $XDEBUG_REMOTE_ENABLE == true ]]; then
        echo "xdebug.mode=develop,debug" | tee -a /usr/local/etc/php/conf.d/xdebug.ini > /dev/null
        echo "xdebug.start_with_request=yes" | tee -a /usr/local/etc/php/conf.d/xdebug.ini > /dev/null
    else
        echo "xdebug.mode=develop" | tee -a /usr/local/etc/php/conf.d/xdebug.ini > /dev/null
    fi

    if [[ -z $XDEBUG_REMOTE_HOST ]]; then
        XDEBUG_REMOTE_HOST=`/sbin/ip route|awk '/default/ { print $3 }'`
    fi

    echo "xdebug.client_host=${XDEBUG_REMOTE_HOST}"  | tee -a  /usr/local/etc/php/conf.d/xdebug.ini > /dev/null
fi

# Executa o comando original
exec "$@"
