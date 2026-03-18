type ClashInfoDto = {
  id: number,
  nameKey: string,
  nameKeySecondary: string,
  schedule: ClashInfoScheduleDto[],
  themeId: number,
};

type ClashInfoScheduleDto = {
  id: number,
  cancelled: boolean,
  registrationTime: number,
  startTime: number,
}

type ClashInfo = {
  id: number,
  theme: string,
  day: number,
  startTime: Date,
  registrationTime: Date,
}

export type { ClashInfoDto, ClashInfoScheduleDto, ClashInfo };
