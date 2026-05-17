/**
 * src/lib/formulaParser.ts
 * ─────────────────────────────────────────────────────────────────────────────
 * Secure Formula Parser Engine — Parametric Estimator
 *
 * PURPOSE:
 *   Safely evaluates math formula strings stored in TemplateComponent.formula
 *   by substituting the variables W (width in mm) and H (height in mm).
 *
 * SECURITY MODEL:
 *   ✅ NO eval(), NO Function(), NO dynamic code execution
 *   ✅ Strict token whitelist: numbers, W, H, +, -, *, /, (, ), whitespace
 *   ✅ Any unrecognized character causes an immediate, descriptive error
 *   ✅ Formula is validated at creation time AND at evaluation time
 *   ✅ Division by zero is caught and returns a clear error
 *
 * SUPPORTED SYNTAX:
 *   • Arithmetic operators: + - * /
 *   • Grouping: ( )
 *   • Variables: W (width in mm), H (height in mm)   [case-insensitive]
 *   • Numbers: integers and decimals (e.g., 35, 6.5, 0.5)
 *   • Standard operator precedence: * / before + -
 *   • Unary minus: e.g., "-H" or "-(W + 10)"
 *
 * EXAMPLES:
 *   evalFormula("H - 35",        { W: 2000, H: 1500 }) → 1465
 *   evalFormula("W",             { W: 2000, H: 1500 }) → 2000
 *   evalFormula("W / 2 + 10",   { W: 2000, H: 1500 }) → 1010
 *   evalFormula("(W - 40) / 2", { W: 2000, H: 1500 }) → 980
 *   evalFormula("H * 0.5",      { W: 2000, H: 1500 }) → 750
 *
 * ARCHITECTURE:
 *   Implements a classic Recursive-Descent Parser (RDP) with:
 *     Tokenizer → Token stream → Parser (Expression → Term → Factor → Atom)
 *
 *   Grammar (EBNF):
 *     expression := term ( ('+' | '-') term )*
 *     term       := factor ( ('*' | '/') factor )*
 *     factor     := unary_minus | atom
 *     atom       := NUMBER | VARIABLE | '(' expression ')'
 * ─────────────────────────────────────────────────────────────────────────────
 */

// ─── Token Types ──────────────────────────────────────────────────────────────

type TokenType =
  | "NUMBER"
  | "VARIABLE"
  | "PLUS"
  | "MINUS"
  | "STAR"
  | "SLASH"
  | "LPAREN"
  | "RPAREN"
  | "EOF";

interface Token {
  type: TokenType;
  value: string; // raw string from source
}

// ─── Variables ────────────────────────────────────────────────────────────────

export interface FormulaVariables {
  W: number; // Width in mm (user input)
  H: number; // Height in mm (user input)
}

// ─── Result Types ─────────────────────────────────────────────────────────────

export type FormulaResult =
  | { ok: true; value: number }
  | { ok: false; error: string };

// ─── Tokenizer ────────────────────────────────────────────────────────────────

/**
 * Converts a formula string into a flat array of tokens.
 * Throws FormulaError immediately on any unrecognized character.
 */
function tokenize(formula: string): Token[] {
  const tokens: Token[] = [];
  let i = 0;

  while (i < formula.length) {
    const ch = formula[i];

    // Skip whitespace
    if (ch === " " || ch === "\t" || ch === "\n") {
      i++;
      continue;
    }

    // Numbers: integer or decimal (e.g., 35, 6.5, 0.5, .5)
    if ((ch >= "0" && ch <= "9") || ch === ".") {
      let raw = "";
      while (
        i < formula.length &&
        ((formula[i] >= "0" && formula[i] <= "9") || formula[i] === ".")
      ) {
        raw += formula[i++];
      }
      // Validate: not more than one decimal point
      if ((raw.match(/\./g) ?? []).length > 1) {
        throw new FormulaError(`Invalid number literal: "${raw}"`);
      }
      tokens.push({ type: "NUMBER", value: raw });
      continue;
    }

    // Variables: W or H (case-insensitive)
    if (ch === "W" || ch === "w") {
      tokens.push({ type: "VARIABLE", value: "W" });
      i++;
      continue;
    }
    if (ch === "H" || ch === "h") {
      tokens.push({ type: "VARIABLE", value: "H" });
      i++;
      continue;
    }

    // Operators and grouping
    if (ch === "+") { tokens.push({ type: "PLUS",   value: "+" }); i++; continue; }
    if (ch === "-") { tokens.push({ type: "MINUS",  value: "-" }); i++; continue; }
    if (ch === "*") { tokens.push({ type: "STAR",   value: "*" }); i++; continue; }
    if (ch === "/") { tokens.push({ type: "SLASH",  value: "/" }); i++; continue; }
    if (ch === "(") { tokens.push({ type: "LPAREN", value: "(" }); i++; continue; }
    if (ch === ")") { tokens.push({ type: "RPAREN", value: ")" }); i++; continue; }

    // Any other character is illegal
    throw new FormulaError(
      `Illegal character "${ch}" at position ${i} in formula: "${formula}". ` +
      `Only numbers, W, H, +, -, *, /, (, ) are allowed.`
    );
  }

  tokens.push({ type: "EOF", value: "" });
  return tokens;
}

// ─── FormulaError ─────────────────────────────────────────────────────────────

/** Typed error class for formula parsing/evaluation errors */
class FormulaError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "FormulaError";
  }
}

// ─── Recursive-Descent Parser ─────────────────────────────────────────────────

class Parser {
  private tokens: Token[];
  private pos: number = 0;
  private vars: FormulaVariables;

  constructor(tokens: Token[], vars: FormulaVariables) {
    this.tokens = tokens;
    this.vars = vars;
  }

  private peek(): Token {
    return this.tokens[this.pos];
  }

  private consume(expected?: TokenType): Token {
    const tok = this.tokens[this.pos++];
    if (expected && tok.type !== expected) {
      throw new FormulaError(
        `Expected token "${expected}" but got "${tok.type}" ("${tok.value}")`
      );
    }
    return tok;
  }

  /**
   * expression := term ( ('+' | '-') term )*
   * Handles addition and subtraction (lowest precedence).
   */
  parseExpression(): number {
    let left = this.parseTerm();

    while (
      this.peek().type === "PLUS" ||
      this.peek().type === "MINUS"
    ) {
      const op = this.consume();
      const right = this.parseTerm();
      left = op.type === "PLUS" ? left + right : left - right;
    }

    return left;
  }

  /**
   * term := factor ( ('*' | '/') factor )*
   * Handles multiplication and division (higher precedence).
   */
  private parseTerm(): number {
    let left = this.parseFactor();

    while (
      this.peek().type === "STAR" ||
      this.peek().type === "SLASH"
    ) {
      const op = this.consume();
      const right = this.parseFactor();

      if (op.type === "SLASH") {
        if (right === 0) {
          throw new FormulaError("Division by zero in formula.");
        }
        left = left / right;
      } else {
        left = left * right;
      }
    }

    return left;
  }

  /**
   * factor := '-' factor | atom
   * Handles unary negation (e.g., -H, -(W + 10)).
   */
  private parseFactor(): number {
    if (this.peek().type === "MINUS") {
      this.consume("MINUS");
      return -this.parseFactor();
    }
    return this.parseAtom();
  }

  /**
   * atom := NUMBER | VARIABLE | '(' expression ')'
   * The leaf nodes: literals, variables, and parenthesized sub-expressions.
   */
  private parseAtom(): number {
    const tok = this.peek();

    if (tok.type === "NUMBER") {
      this.consume("NUMBER");
      const val = parseFloat(tok.value);
      if (isNaN(val)) {
        throw new FormulaError(`Cannot parse number: "${tok.value}"`);
      }
      return val;
    }

    if (tok.type === "VARIABLE") {
      this.consume("VARIABLE");
      if (tok.value === "W") return this.vars.W;
      if (tok.value === "H") return this.vars.H;
      // Should never reach here — tokenizer already validates variable names
      throw new FormulaError(`Unknown variable: "${tok.value}"`);
    }

    if (tok.type === "LPAREN") {
      this.consume("LPAREN");
      const val = this.parseExpression();
      this.consume("RPAREN");
      return val;
    }

    throw new FormulaError(
      `Unexpected token "${tok.type}" ("${tok.value}") — expected a number, variable, or "(`
    );
  }
}

// ─── Public API ───────────────────────────────────────────────────────────────

/**
 * Safely evaluates an arithmetic formula string with W and H substituted.
 *
 * Returns a `FormulaResult` discriminated union:
 *   { ok: true,  value: number }   — success; `value` is the cut length in mm
 *   { ok: false, error: string }   — failure; `error` is a human-readable message
 *
 * NEVER throws — all errors are captured and returned as { ok: false }.
 *
 * @param formula   Formula string, e.g. "H - 35", "W / 2 + 10"
 * @param vars      The W and H values to inject (in mm)
 *
 * @example
 *   evalFormula("H - 35",      { W: 2000, H: 1500 }) → { ok: true, value: 1465 }
 *   evalFormula("W / 2 + 10",  { W: 2000, H: 1500 }) → { ok: true, value: 1010 }
 *   evalFormula("H - 35 + $",  { W: 2000, H: 1500 }) → { ok: false, error: 'Illegal character...' }
 */
export function evalFormula(
  formula: string,
  vars: FormulaVariables
): FormulaResult {
  try {
    if (!formula || formula.trim() === "") {
      return { ok: false, error: "Formula is empty." };
    }

    const tokens = tokenize(formula.trim());
    const parser = new Parser(tokens, vars);
    const value = parser.parseExpression();

    // Ensure we consumed the entire formula (no trailing garbage)
    const remaining = parser["peek"](); // access via bracket to keep class clean
    if (remaining.type !== "EOF") {
      return {
        ok: false,
        error: `Unexpected content after formula end: "${remaining.value}"`,
      };
    }

    if (!isFinite(value)) {
      return { ok: false, error: "Formula produced a non-finite result (Infinity or NaN)." };
    }

    return { ok: true, value };
  } catch (err) {
    if (err instanceof FormulaError) {
      return { ok: false, error: err.message };
    }
    // Unexpected error — don't expose internals
    return { ok: false, error: "An unexpected error occurred while parsing the formula." };
  }
}

/**
 * Validates a formula string WITHOUT substituting real W/H values.
 * Uses W=1000, H=1000 as dummy values — sufficient to catch structural errors.
 *
 * Use this at template creation/update time to reject invalid formulas early.
 *
 * @returns `{ valid: true }` or `{ valid: false, error: string }`
 */
export function validateFormula(
  formula: string
): { valid: true } | { valid: false; error: string } {
  const result = evalFormula(formula, { W: 1000, H: 1000 });
  if (result.ok) {
    return { valid: true };
  }
  return { valid: false, error: result.error };
}

/**
 * Evaluates an array of formula strings for the same W/H, returning
 * all results in one pass. Useful for processing a full template's component list.
 *
 * @param formulas  Array of { label, formula, quantity } objects
 * @param vars      The W and H values (mm)
 * @returns         Array of evaluated cut lengths with metadata
 */
export interface FormulaInput {
  label: string;
  formula: string;
  quantity: number; // number of identical cuts at this length
  materialId: string;
  barLengthMm?: number | null; // per-component override (null = use template default)
}

export interface EvaluatedCut {
  label: string;
  materialId: string;
  cutLengthMm: number;       // the evaluated cut length (mm)
  quantity: number;
  barLengthMm: number | null; // null = use template default
}

export type BatchFormulaResult =
  | { ok: true;  cuts: EvaluatedCut[] }
  | { ok: false; error: string; failedLabel: string };

export function evalFormulasBatch(
  formulas: FormulaInput[],
  vars: FormulaVariables,
  defaultBarLengthMm: number
): BatchFormulaResult {
  const cuts: EvaluatedCut[] = [];

  for (const input of formulas) {
    const result = evalFormula(input.formula, vars);

    if (!result.ok) {
      return {
        ok: false,
        error: `Formula error in component "${input.label}": ${result.error}`,
        failedLabel: input.label,
      };
    }

    const cutLengthMm = Math.round(result.value); // round to nearest mm

    if (cutLengthMm <= 0) {
      return {
        ok: false,
        error: `Formula "${input.formula}" for component "${input.label}" evaluated to ${cutLengthMm}mm — cut length must be positive.`,
        failedLabel: input.label,
      };
    }

    const effectiveBarLength = input.barLengthMm ?? defaultBarLengthMm;
    if (cutLengthMm > effectiveBarLength) {
      return {
        ok: false,
        error: `Component "${input.label}": cut length ${cutLengthMm}mm exceeds bar length ${effectiveBarLength}mm. Check the formula or bar length configuration.`,
        failedLabel: input.label,
      };
    }

    cuts.push({
      label: input.label,
      materialId: input.materialId,
      cutLengthMm,
      quantity: input.quantity,
      barLengthMm: input.barLengthMm ?? null,
    });
  }

  return { ok: true, cuts };
}
