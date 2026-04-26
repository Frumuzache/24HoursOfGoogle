type SafetySuggestionsInput = {
  intensity: number;
  hasTakenMedication: boolean;
};

type SafetySuggestions = {
  priority: "low" | "medium" | "high";
  actions: string[];
};

export function buildSafetySuggestions(input: SafetySuggestionsInput): SafetySuggestions {
  const actions: string[] = [];

  if (!input.hasTakenMedication) {
    actions.push("Check whether your prescribed medication was taken as directed.");
  }

  actions.push("Do one grounding round: name 5 things you see, 4 you feel, 3 you hear, 2 you smell, and 1 you taste.");
  actions.push("Search for a nearby calm place now (for example a park, library, or cafe). Keep directions ready.");

  if (input.intensity >= 8) {
    actions.push("Take 6 slow breaths: inhale 4 seconds, exhale 6 seconds.");
    actions.push("Move to a safer and quieter area if possible, then call your emergency contact or local support line.");
    actions.push("Contact your emergency contact or local support line now.");
    return { priority: "high", actions };
  }

  if (input.intensity >= 5) {
    actions.push("Take a short guided breathing break (inhale 4 seconds, exhale 6 seconds for 4 rounds).");
    actions.push("Drink some water and sit down for two minutes before deciding the next step.");
    return { priority: "medium", actions };
  }

  actions.push("Do one calming activity you enjoy for 10 minutes, then check in with how you feel.");
  return { priority: "low", actions };
}