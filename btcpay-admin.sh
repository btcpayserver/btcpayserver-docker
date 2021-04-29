#!/bin/bash
query()
{
    docker exec $(docker ps -a -q -f "name=postgres_1") psql -U postgres -d btcpayservermainnet -c "$*"
}

case "$1" in
    disable-multifactor)
        query "DELETE FROM \"U2FDevices\" WHERE \"ApplicationUserId\" = (SELECT \"Id\" FROM \"AspNetUsers\" WHERE upper('$2') = \"NormalizedEmail\")"
        query "DELETE FROM \"Fido2Credentials\" WHERE \"ApplicationUserId\" = (SELECT \"Id\" FROM \"AspNetUsers\" WHERE upper('$2') = \"NormalizedEmail\")"
        query "UPDATE public.\"AspNetUsers\" SET \"TwoFactorEnabled\"=false WHERE upper('\$2') = \"NormalizedEmail\""
        ;;
	set-user-admin)
        query "INSERT INTO \"AspNetUserRoles\" Values ( (SELECT \"Id\" FROM \"AspNetUsers\" WHERE upper('$2') = \"NormalizedEmail\"), (SELECT \"Id\" FROM \"AspNetRoles\" WHERE \"NormalizedName\"='SERVERADMIN'))"
        ;;
    reset-server-policy)
        query "DELETE FROM \"Settings\" WHERE \"Id\" = 'BTCPayServer.Services.PoliciesSettings'"
        ;;
    *)
        echo "Usage: $0 [command]"
        echo
        echo "Commands:"
        echo "         disable-multifactor <email>"
        echo "         set-user-admin <email>"
        echo "         reset-server-policy"
esac

exit 0
