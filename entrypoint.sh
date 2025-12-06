#!/bin/sh
set -e

# Wait for the database to be available
wait_for_db() {
	host=${DB_HOST:-strichliste-db}
	user=${MYSQL_USER:-strichliste}
	pass=${MYSQL_PASSWORD}

	if [ -z "$pass" ]; then
		echo "Error: MYSQL_PASSWORD environment variable is not set or empty"
		exit 1
	fi
	echo "Waiting for database ${host}..."
	# Try mysql client first (installed in image)
	until MYSQL_PWD="$pass" mysql -h "$host" -u"$user" -e 'SELECT 1' >/dev/null 2>&1; do
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
		if ! php /source/bin/console doctrine:schema:create --no-interaction; then
			echo "Warning: Schema creation failed, continuing anyway..."
		fi
	fi
}

# Start nginx and php-fpm in foreground to keep container running
start_services() {
	echo "Starting nginx and php-fpm in foreground"
	nginx -g 'daemon off;' &
	NGINX_PID=$!
	php-fpm81 -F &
	PHP_FPM_PID=$!

	# Wait for either process to exit
	wait -n
	# If either exits, kill the other and exit
	kill $NGINX_PID $PHP_FPM_PID 2>/dev/null
	exit 1
}

# Main execution
wait_for_db
run_migrations_or_schema
start_services
