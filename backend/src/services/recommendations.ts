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
    actions.push("Check if your prescribed medication was taken as directed.");
  }

  actions.push("Use a grounding exercise: 5 things you see, 4 feel, 3 hear, 2 smell, 1 taste.");
  actions.push("Move to a calmer nearby location (for example, park or library). ");

  if (input.intensity >= 8) {
    actions.push("Contact your emergency contact or local support line now.");
    return { priority: "high", actions };
  }

  if (input.intensity >= 5) {
    actions.push("Take a short guided breathing break (4-7-8 pattern for 3 cycles).");
    return { priority: "medium", actions };
  }

  actions.push("Do one calming hobby activity for 10 minutes.");
  return { priority: "low", actions };
}
