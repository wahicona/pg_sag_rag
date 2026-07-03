#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="${ROOT_DIR}/outputs/compat"
RESULTS_FILE="${RESULTS_DIR}/pg_matrix_results.txt"

mkdir -p "${RESULTS_DIR}"
: > "${RESULTS_FILE}"

for version in 14 15 16 17; do
  name="pg_sag_rag_pg${version}"
  image="pg_sag_rag:test-pg${version}"

  echo "== Building PostgreSQL ${version} test image ==" | tee -a "${RESULTS_FILE}"
  docker build --build-arg "PG_MAJOR=${version}" -t "${image}" "${ROOT_DIR}" | tee -a "${RESULTS_FILE}"

  echo "== Testing PostgreSQL ${version} ==" | tee -a "${RESULTS_FILE}"
  docker rm -f "${name}" >/dev/null 2>&1 || true
  docker run -d --name "${name}" \
    -e POSTGRES_DB=rag \
    -e POSTGRES_USER=postgres \
    -e POSTGRES_PASSWORD=postgres \
    -v "${ROOT_DIR}:/workspace:ro" \
    "${image}" >/dev/null

  for _ in $(seq 1 60); do
    if docker exec "${name}" pg_isready -U postgres -d rag >/dev/null 2>&1; then
      break
    fi
    sleep 1
  done

  docker exec "${name}" psql -U postgres -d rag -c \
    "SELECT version(); SELECT name, default_version FROM pg_available_extensions WHERE name IN ('vector','pg_trgm','pg_sag_rag') ORDER BY name;" \
    | tee -a "${RESULTS_FILE}"

  for test_file in tests/smoke.sql tests/benchmark.sql tests/profile.sql tests/router.sql; do
    echo "-- ${test_file}" | tee -a "${RESULTS_FILE}"
    docker exec -i "${name}" psql -v ON_ERROR_STOP=1 -U postgres -d rag -f "/workspace/${test_file}" \
      | tee -a "${RESULTS_FILE}"
    echo "PASS ${test_file}" | tee -a "${RESULTS_FILE}"
  done

  docker rm -f "${name}" >/dev/null
  echo "PASS PostgreSQL ${version}" | tee -a "${RESULTS_FILE}"
  echo | tee -a "${RESULTS_FILE}"
done

echo "Compatibility matrix results written to ${RESULTS_FILE}"
