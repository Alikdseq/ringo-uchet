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
      staleTime: 30_000, // 30 секунд - данные считаются свежими
      // Включаем refetch при фокусе окна для real-time обновлений
      refetchOnWindowFocus: true,
      // Включаем refetch при переподключении сети
      refetchOnReconnect: true,
      // Включаем refetch при монтировании (если данные устарели)
      refetchOnMount: true,
      // Используем предыдущие данные во время обновления для плавности (без мерцаний)
      placeholderData: (previousData) => previousData,
      // Не показываем loading состояние при background refetch
      notifyOnChangeProps: ["data", "error"],
    },
    mutations: {
      // При мутациях автоматически инвалидируем связанные запросы
      onSettled: () => {
        // Инвалидируем все связанные запросы после любой мутации
        void queryClient.invalidateQueries();
      },
    },
  },
});


