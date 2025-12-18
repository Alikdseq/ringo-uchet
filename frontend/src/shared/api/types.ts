export interface PaginatedResponse<T> {
  count: number;
  next: string | null;
  previous: string | null;
  results: T[];
}

export type MaybePaginated<T> = T[] | PaginatedResponse<T>;

export interface ApiErrorBody {
  detail?: string;
  non_field_errors?: string[];
  [key: string]: unknown;
}


