import React from "react";

export interface DataTableColumn<T> {
  key: keyof T;
  header: string;
  render?: (row: T) => React.ReactNode;
}

interface DataTableProps<T> {
  columns: DataTableColumn<T>[];
  data: T[];
  emptyText?: string;
  /**
   * Максимальное количество строк, одновременно отображаемых в DOM.
   * Если данных больше, будет показано только первые N с пометкой внизу.
   * Это простая форма "виртуализации", чтобы не рендерить сотни/тысячи строк.
   */
  maxVisibleRows?: number;
}

export function DataTable<T extends { id?: string | number }>({
  columns,
  data,
  emptyText = "Нет данных для отображения",
  maxVisibleRows,
}: DataTableProps<T>) {
  if (data.length === 0) {
    return (
      <div className="rounded-lg border border-dashed border-slate-200 bg-slate-50 px-4 py-6 text-center text-xs text-slate-500">
        {emptyText}
      </div>
    );
  }

  const visibleData =
    typeof maxVisibleRows === "number" && maxVisibleRows > 0 && data.length > maxVisibleRows
      ? data.slice(0, maxVisibleRows)
      : data;

  const isTruncated = visibleData.length < data.length;

  return (
    <div className="overflow-hidden rounded-lg border border-slate-200 bg-white">
      <table className="min-w-full divide-y divide-slate-200 text-sm">
        <thead className="bg-slate-50">
          <tr>
            {columns.map((column) => (
              <th
                key={String(column.key)}
                scope="col"
                className="px-3 py-2 text-left text-xs font-semibold uppercase tracking-wide text-slate-500"
              >
                {column.header}
              </th>
            ))}
          </tr>
        </thead>
        <tbody className="divide-y divide-slate-100 bg-white">
          {visibleData.map((row, rowIndex) => (
            <tr key={(row.id as string | number | undefined) ?? rowIndex}>
              {columns.map((column) => (
                <td
                  key={String(column.key)}
                  className="whitespace-nowrap px-3 py-2 text-xs text-slate-700"
                >
                  {column.render
                    ? column.render(row)
                    : String(row[column.key] ?? "")}
                </td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
      {isTruncated ? (
        <div className="border-t border-slate-200 bg-slate-50 px-3 py-1.5 text-[10px] text-slate-500">
          Показаны первые {visibleData.length} из {data.length} записей.
          Уточните фильтры или поиск, чтобы сузить выборку.
        </div>
      ) : null}
    </div>
  );
}


