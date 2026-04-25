import cors from "cors";
import express from "express";
import { env } from "./core/config";
import { initializeDatabase, verifyDatabaseConnection } from "./core/db";
import { healthRouter } from "./api/routes/health";
import { profilesRouter } from "./api/routes/profiles";
import { checkinsRouter } from "./api/routes/checkins";
import { vitalsRouter } from "./api/routes/vitals";

const app = express();

app.use(cors());
app.use(express.json({ limit: "1mb" }));

app.get("/", (_req, res) => {
  res.status(200).json({
    service: "mental-safety-backend",
    version: "0.1.0",
    docs: "/api/v1/health",
  });
});

app.use("/api/v1", healthRouter);
app.use("/api/v1", profilesRouter);
app.use("/api/v1", checkinsRouter);
app.use("/api/v1", vitalsRouter);

app.use((err: unknown, _req: express.Request, res: express.Response, _next: express.NextFunction) => {
  console.error("Unhandled API error", err);
  res.status(500).json({ error: "Internal server error" });
});

async function start(): Promise<void> {
  initializeDatabase();
  await verifyDatabaseConnection();

  app.listen(env.PORT, "0.0.0.0", () => {
    console.log(`Backend listening on port ${env.PORT}`);
  });
}

start().catch((error) => {
  console.error("Failed to start backend", error);
  process.exit(1);
});
