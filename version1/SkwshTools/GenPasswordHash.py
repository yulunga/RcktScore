# GenPasswordHash.py
# to run - python3 GenPasswordHash.py

from werkzeug.security import generate_password_hash

def hash_password(plain_password):
    return generate_password_hash(plain_password)

if __name__ == "__main__":
    password = input("Enter password to hash: ").strip()
    hashed = hash_password(password)
    print("\nHashed password:")
    print(hashed)
