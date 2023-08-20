#include "libpq-fe.h"
#include <stdio.h>

int main() {
  PGconn *conn = PQconnectdb("host=localhost port=9432 user=auth password=password dbname=auth");
  if (PQstatus(conn) != CONNECTION_OK) {
    fprintf(stderr, "%s", PQerrorMessage(conn));
    goto die;
  }
  PGresult *res = PQexec(conn, "SELECT * FROM users;");
  if (PQresultStatus(res) != PGRES_TUPLES_OK) {
    fprintf(stderr, "%s", PQerrorMessage(conn));
    goto die;  
  }
  int nFields = PQnfields(res);
  for (int i = 0; i < nFields; i++) {
    printf("%-20s", PQfname(res, i));
  }
  printf("\n\n");
  for (int i = 0; i < PQntuples(res); i++) {
    for (int j = 0; j < nFields; j++) {
      printf("%-20s", PQgetvalue(res, i, j));
    }
    printf("\n");
  }
  PQclear(res);
  die:
  PQfinish(conn);
  return 0;
}
