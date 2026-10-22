#!/bin/bash
query()
{
    local statement="$1"
    shift
    printf '%s\n' "$statement" | docker exec -i "$(docker ps -a -q -f "name=postgres_1")" \
        psql -U postgres -d btcpayservermainnet \
        --set=ON_ERROR_STOP=1 "$@" -f -
}

case "$1" in
    disable-multifactor)
        query "DELETE FROM \"U2FDevices\" WHERE \"ApplicationUserId\" = (SELECT \"Id\" FROM \"AspNetUsers\" WHERE upper(:'email') = \"NormalizedEmail\")" --set=email="$2"
        query "DELETE FROM \"Fido2Credentials\" WHERE \"ApplicationUserId\" = (SELECT \"Id\" FROM \"AspNetUsers\" WHERE upper(:'email') = \"NormalizedEmail\")" --set=email="$2"
        query "UPDATE public.\"AspNetUsers\" SET \"TwoFactorEnabled\"=false WHERE upper(:'email') = \"NormalizedEmail\"" --set=email="$2"
        ;;
	set-user-admin)
        query "INSERT INTO \"AspNetUserRoles\" Values ( (SELECT \"Id\" FROM \"AspNetUsers\" WHERE upper(:'email') = \"NormalizedEmail\"), (SELECT \"Id\" FROM \"AspNetRoles\" WHERE \"NormalizedName\"='SERVERADMIN'))" --set=email="$2"
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
