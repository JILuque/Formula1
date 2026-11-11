
import secrets

import snowflake.snowpark as snowpark
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import rsa


def main(session: snowpark.Session):
    passphrase = secrets.token_urlsafe(18)
    key = rsa.generate_private_key(public_exponent=65537, key_size=2048)

    # PKCS#8 cifrado (AES-256-CBC con PBKDF2), el formato que recomienda dbt v2
    privada = key.private_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PrivateFormat.PKCS8,
        encryption_algorithm=serialization.BestAvailableEncryption(passphrase.encode()),
    ).decode()

    publica = key.public_key().public_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PublicFormat.SubjectPublicKeyInfo,
    ).decode()
    # Snowflake espera la clave pública sin las líneas BEGIN/END y sin saltos de línea
    cuerpo = "".join(linea for linea in publica.splitlines() if "-----" not in linea)

    usuario = session.sql("select current_user()").collect()[0][0]
    alter_user = f'alter user "{usuario}" set rsa_public_key = \'{cuerpo}\';'

    # print() escribe en la pestaña Output del worksheet, que respeta los saltos
    # de línea del PEM y permite copiar la clave de una vez. Un DataFrame los
    # perdería y obligaría a pelearse con la celda del grid.
    print("=" * 70)
    print("1 · CLAVE PRIVADA: pégala entera en dbt Platform (con BEGIN/END)")
    print("=" * 70)
    print(privada)
    print("=" * 70)
    print("2 · PASSPHRASE: pégala en dbt Platform")
    print("=" * 70)
    print(passphrase)
    print()
    print("=" * 70)
    print("3 · Ejecuta esto en una worksheet SQL con SECURITYADMIN")
    print("=" * 70)
    print(alter_user)

    return f"Listo. Clave generada para el usuario {usuario}. Mira la pestaña Output."


# En un Python Worksheet, Snowsight llama a main(session) por su cuenta. En un
# fichero .py de un Workspace no: el script se ejecuta de arriba a abajo, así que
# hay que pedir la sesión activa y llamar a main nosotros.
if __name__ == "__main__":
    from snowflake.snowpark.context import get_active_session

    print(main(get_active_session()))
