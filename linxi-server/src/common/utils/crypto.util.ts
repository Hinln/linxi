import * as CryptoJS from 'crypto-js';

export class CryptoUtil {
  private static readonly SECRET_KEY = process.env.CRYPTO_SECRET_KEY || 'default_secret_key_32_chars_minimum!';

  /**
   * Encrypts the given text using AES.
   * @param text The plaintext to encrypt.
   * @returns The encrypted text (Base64 encoded).
   */
  static encrypt(text: string): string {
    if (!text) return text;
    return CryptoJS.AES.encrypt(text, this.SECRET_KEY).toString();
  }

  /**
   * Decrypts the given encrypted text using AES.
   * @param encryptedText The encrypted text (Base64 encoded).
   * @returns The decrypted plaintext.
   */
  static decrypt(encryptedText: string): string {
    if (!encryptedText) return encryptedText;
    const bytes = CryptoJS.AES.decrypt(encryptedText, this.SECRET_KEY);
    return bytes.toString(CryptoJS.enc.Utf8);
  }
}
