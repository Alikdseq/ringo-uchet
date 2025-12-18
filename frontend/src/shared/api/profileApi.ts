import { httpClient } from "./httpClient";
import type { OperatorSalaryResponse } from "@/shared/types/salary";
import { mapOperatorSalaryFromApi } from "@/shared/types/salary";

export const ProfileApi = {
  async getOperatorSalary(): Promise<OperatorSalaryResponse> {
    const response = await httpClient.get("/users/operator/salary/");
    return mapOperatorSalaryFromApi(response.data);
  },
};


