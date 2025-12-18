import { QueryClient } from "@tanstack/react-query";

export const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      // Поведение по умолчанию для большинства запросов
      retry: (failureCount, error) => {
        if (failureCount >= 2) return false;
        // При 401/403/404 бессмысленно ретраить
        const anyError = error as { status?: number };
        if (!anyError.status) return true;
        if ([401, 403, 404].includes(anyError.status)) return false;
        return true;
      },
      // Общий staleTime, для справочников он будет увеличен на уровне отдельных хуков
      staleTime: 60_000,
      // Чтобы не дергать лишние рефетчи при каждом фокусе окна
      refetchOnWindowFocus: false,
    },
  },
});


