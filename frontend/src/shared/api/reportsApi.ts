import { httpClient } from "./httpClient";
import type {
  EmployeeReportItem,
  EquipmentReportItem,
  SummaryReport,
} from "@/shared/types/reports";
import {
  mapEmployeeReportFromApi,
  mapEquipmentReportFromApi,
  mapSummaryReportFromApi,
} from "@/shared/types/reports";

export interface ReportsPeriodParams {
  from?: string;
  to?: string;
}

function buildQuery(params: ReportsPeriodParams): Record<string, string> {
  const query: Record<string, string> = {};
  if (params.from) query.from = params.from;
  if (params.to) query.to = params.to;
  return query;
}

export const ReportsApi = {
  async getSummary(params: ReportsPeriodParams = {}): Promise<SummaryReport> {
    const response = await httpClient.get<unknown>("/reports/summary/", {
      params: buildQuery(params),
    });
    return mapSummaryReportFromApi(response.data);
  },

  async getByEquipment(
    params: ReportsPeriodParams = {},
  ): Promise<EquipmentReportItem[]> {
    const response = await httpClient.get<unknown[]>("/reports/equipment/", {
      params: buildQuery(params),
    });
    const raw = Array.isArray(response.data) ? response.data : [];
    return raw.map((item) => mapEquipmentReportFromApi(item));
  },

  async getByEmployees(
    params: ReportsPeriodParams = {},
  ): Promise<EmployeeReportItem[]> {
    const response = await httpClient.get<unknown[]>("/reports/employees/", {
      params: buildQuery(params),
    });
    const raw = Array.isArray(response.data) ? response.data : [];
    return raw.map((item) => mapEmployeeReportFromApi(item));
  },
};


