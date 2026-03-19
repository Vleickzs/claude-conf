export interface HookInput {
	tool_name: string;
	tool_input: {
		command?: string;
	};
	session_id?: string;
}

export interface ValidationResult {
	isValid: boolean;
	severity: "LOW" | "MEDIUM" | "HIGH" | "CRITICAL";
	violations: string[];
	sanitizedCommand: string;
	action: "allow" | "deny" | "ask";
}

export interface HookOutput {
	hookSpecificOutput: {
		hookEventName: string;
		permissionDecision: "allow" | "block" | "ask";
		permissionDecisionReason: string;
	};
}
