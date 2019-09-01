#!/bin/bash
query()
{
    docker exec $(docker ps -a -q -f "name=postgres_1") psql -U postgres -d btcpayservermainnet -c "$*"
}

case "$1" in
    reset-u2f)
        query "SELECT * FROM \"U2FDevices\""
        query "UPDATE public.\"AspNetUsers\" SET \"TwoFactorEnabled\"=false WHERE upper('\$1') = \"NormalizedEmail\""
        query "SELECT * FROM \"U2FDevices\""
        ;;
    *)
        echo "Usage: $0 [command]"
        echo
        echo "Commands:"
        echo "         reset-u2f"
        echo "         reset-u2f"
esac

exit 0
