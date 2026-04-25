import { Router } from "express";
import { db } from "../../core/db";

export const healthRouter = Router();

healthRouter.get("/health", async (_req, res) => {
  try {
    db.prepare("SELECT 1").get();
    res.status(200).json({ status: "ok", database: "connected" });
  } catch {
    res.status(503).json({ status: "degraded", database: "disconnected" });
  }
});
