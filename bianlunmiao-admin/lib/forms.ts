import type {
  FieldPath,
  FieldValues,
  UseFormSetError,
} from "react-hook-form"
import type { ZodError } from "zod/v4"

export function applyZodIssues<TFieldValues extends FieldValues>(
  error: ZodError<TFieldValues>,
  setError: UseFormSetError<TFieldValues>
) {
  for (const issue of error.issues) {
    const name = issue.path.join(".")

    if (!name) {
      continue
    }

    setError(name as FieldPath<TFieldValues>, {
      type: "manual",
      message: issue.message,
    })
  }
}
