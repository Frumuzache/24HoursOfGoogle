import { Router, Request, Response } from 'express';
import bcrypt from 'bcrypt';
import { db } from '../../core/db';

const router = Router();

/**
 * @route   POST /api/v1/auth/register
 * @desc    Înregistrează un utilizator nou și îi creează automat profilul
 */
router.post('/register', async (req: Request, res: Response) => {
    const { email, password, displayName } = req.body;

    // Validare minimă
    if (!email || !password || !displayName) {
        return res.status(400).json({ error: "Toate câmpurile sunt obligatorii (email, password, displayName)." });
    }

    try {
        // 1. Verificăm dacă userul există deja
        const existingUser = db.prepare('SELECT id FROM users WHERE email = ?').get(email);
        if (existingUser) {
            return res.status(400).json({ error: "Acest email este deja înregistrat." });
        }

        // 2. Criptăm parola
        const saltRounds = 10;
        const hashedPassword = await bcrypt.hash(password, saltRounds);

        // 3. Inserăm userul în schema curentă
        const userStmt = db.prepare('INSERT INTO users (email, password, username) VALUES (?, ?, ?)');
        const userResult = userStmt.run(email, hashedPassword, displayName);
        const userId = Number(userResult.lastInsertRowid);

        // 4. Cream profilul utilizatorului
        const profileStmt = db.prepare(
            `INSERT INTO user_profiles (display_name, disorders, calming_strategies, favorite_foods, hobbies, medications)
             VALUES (?, '[]', '[]', '[]', '[]', '[]')`
        );
        const profileResult = profileStmt.run(displayName);
        const profileId = Number(profileResult.lastInsertRowid);

        // 5. Actualizam userul cu profile_id
        db.prepare('UPDATE users SET profile_id = ? WHERE id = ?').run(profileId, userId);

        res.status(201).json({
            message: "Cont creat cu succes!",
            user: {
                id: userId,
                email,
                username: displayName,
                profileId: profileId
            }
        });

    } catch (error) {
        console.error("❌ Eroare la Register:", error);
        res.status(500).json({ error: "Eroare internă de server la înregistrare." });
    }
});

/**
 * @route   POST /api/v1/auth/login
 * @desc    Autentifică utilizatorul și returnează datele de profil
 */
router.post('/login', async (req: Request, res: Response) => {
    const { email, password } = req.body;

    if (!email || !password) {
        return res.status(400).json({ error: "Email-ul și parola sunt obligatorii." });
    }

    try {
        // 1. Căutăm userul în DB
        const user = db.prepare('SELECT id, email, password, username, profile_id FROM users WHERE email = ?').get(email) as
            | { id: number; email: string; password: string; username: string | null; profile_id: number | null }
            | undefined;

        if (!user) {
            return res.status(401).json({ error: "Date de autentificare invalide." });
        }

        // 2. Verificăm parola
        const isMatch = await bcrypt.compare(password, user.password);
        if (!isMatch) {
            return res.status(401).json({ error: "Date de autentificare invalide." });
        }

        res.status(200).json({
            message: "Login reușit!",
            user: {
                id: user.id,
                email: user.email,
                profileId: user.profile_id,
                displayName: user.username || "Utilizator"
            }
        });

    } catch (error) {
        console.error("❌ Eroare la Login:", error);
        res.status(500).json({ error: "Eroare internă de server la login." });
    }
});

export default router;