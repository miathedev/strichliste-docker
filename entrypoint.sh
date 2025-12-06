#!/bin/sh
set -e

# Wait for the database to be available
wait_for_db() {
	host=${DB_HOST:-strichliste-db}
	user=${MYSQL_USER:-strichliste}
	pass=${MYSQL_PASSWORD}
	db=${MYSQL_DATABASE:-strichliste}

	echo "Waiting for database ${host}..."
	# Try mysql client first (installed in image)
	until mysql -h "$host" -u"$user" -p"$pass" -e 'SELECT 1' >/dev/null 2>&1; do
		sleep 1
	done
	echo "Database is available"
}

# Run Migration if not yet applied, else ensure schema
run_migrations_or_schema() {
	cd /source || return
	# Prefer migrations if configured
	if [ -d "migrations" ] || php /source/bin/console list doctrine:migrations:status --no-ansi >/dev/null 2>&1; then
		echo "Running doctrine migrations (if any)..."
		php /source/bin/console doctrine:migrations:migrate --no-interaction || true
	else
		echo "No migrations found, ensuring schema..."
		php /source/bin/console doctrine:schema:create --no-interaction || true
	fi
}

# Start nginx and php-fpm in foreground to keep container running
start_services() {
	echo "Starting nginx and php-fpm in foreground"
	nginx -g 'daemon off;' &
	exec php-fpm81 -F
}

# Main execution
wait_for_db
run_migrations_or_schema
start_services
