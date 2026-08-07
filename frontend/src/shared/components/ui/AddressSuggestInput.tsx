"use client";

import React, { useEffect, useId, useRef, useState } from "react";
import { useDebouncedValue } from "@/shared/hooks";
import { OrdersApi } from "@/shared/api/ordersApi";

interface AddressSuggestInputProps {
  value: string;
  onChange: (value: string) => void;
  rows?: number;
  placeholder?: string;
  className?: string;
  disabled?: boolean;
}

/**
 * Подсказки адресов из БД заявок.
 * Показываются только при ≥3 символах; совпадение по подстроке (icontains).
 */
export function AddressSuggestInput({
  value,
  onChange,
  rows = 3,
  placeholder,
  className,
  disabled,
}: AddressSuggestInputProps) {
  const listId = useId();
  const wrapperRef = useRef<HTMLDivElement>(null);
  const [open, setOpen] = useState(false);
  const [suggestions, setSuggestions] = useState<string[]>([]);
  const [loading, setLoading] = useState(false);
  const debounced = useDebouncedValue(value.trim(), 280);

  useEffect(() => {
    let cancelled = false;

    const run = async () => {
      if (debounced.length < 3) {
        setSuggestions([]);
        setLoading(false);
        return;
      }
      setLoading(true);
      try {
        const list = await OrdersApi.suggestAddresses(debounced);
        if (!cancelled) {
          // Не предлагаем точное совпадение с текущим вводом
          const filtered = list.filter(
            (item) => item.trim().toLowerCase() !== debounced.toLowerCase(),
          );
          setSuggestions(filtered);
          setOpen(filtered.length > 0);
        }
      } catch {
        if (!cancelled) {
          setSuggestions([]);
        }
      } finally {
        if (!cancelled) setLoading(false);
      }
    };

    void run();
    return () => {
      cancelled = true;
    };
  }, [debounced]);

  useEffect(() => {
    const onDocClick = (event: MouseEvent) => {
      if (!wrapperRef.current?.contains(event.target as Node)) {
        setOpen(false);
      }
    };
    document.addEventListener("mousedown", onDocClick);
    return () => document.removeEventListener("mousedown", onDocClick);
  }, []);

  const showDropdown =
    open && !disabled && debounced.length >= 3 && suggestions.length > 0;

  return (
    <div ref={wrapperRef} className="relative">
      <textarea
        className={
          className ??
          "block w-full rounded-md border border-slate-300 px-3 py-1.5 text-xs text-slate-900 shadow-sm outline-none ring-0 placeholder:text-slate-400 focus:border-slate-900"
        }
        rows={rows}
        value={value}
        placeholder={placeholder}
        disabled={disabled}
        autoComplete="off"
        aria-autocomplete="list"
        aria-controls={listId}
        aria-expanded={showDropdown}
        onChange={(event) => {
          onChange(event.target.value);
          setOpen(true);
        }}
        onFocus={() => {
          if (suggestions.length > 0 && value.trim().length >= 3) {
            setOpen(true);
          }
        }}
      />

      {loading && value.trim().length >= 3 ? (
        <div className="pointer-events-none absolute right-2 top-2 text-[10px] text-slate-400">
          …
        </div>
      ) : null}

      <div
        className={`absolute left-0 right-0 z-30 origin-top overflow-hidden rounded-md border border-slate-200 bg-white shadow-lg transition-all duration-200 ease-out ${
          showDropdown
            ? "mt-1 max-h-48 scale-y-100 opacity-100"
            : "pointer-events-none mt-0 max-h-0 scale-y-95 opacity-0"
        }`}
      >
        <ul id={listId} role="listbox" className="max-h-48 overflow-y-auto py-1">
          {suggestions.map((item) => (
            <li key={item} role="option">
              <button
                type="button"
                className="w-full px-3 py-2 text-left text-xs text-slate-800 transition-colors hover:bg-sky-50 hover:text-sky-800"
                onMouseDown={(event) => event.preventDefault()}
                onClick={() => {
                  onChange(item);
                  setOpen(false);
                  setSuggestions([]);
                }}
              >
                {item}
              </button>
            </li>
          ))}
        </ul>
      </div>
    </div>
  );
}
