import type { ClashInfo, ClashInfoDto } from "../types/clash-info.type";

const dtoToDomain = (dtos: ClashInfoDto[]): ClashInfo[] => {
  const mapped: ClashInfo[] = [];
  dtos.forEach((dto) => {
    const split = dto.nameKeySecondary.split('_');
    const clashInfo: ClashInfo = {
      id: dto.id,
      theme: dto.nameKey,
      day: Number.parseInt(split[1]),
      startTime: new Date(dto.schedule[0].startTime),
      registrationTime: new Date(dto.schedule[0].registrationTime),
    };
    mapped.push(clashInfo);
  })
  return mapped;
}

const getTournamentName = (theme: string): string => {
  let name = "";
  switch (theme) {
    case 'noxus':
      name = "Noxus";
      break;
    case 'ionia':
      name = "Ionia";
      break;
    case 'demacia':
      name = "Demacia";
      break;
    case 'piltover':
      name = "Piltover";
      break;
    case 'zaun':
      name = "Zaun";
      break;
    case 'freljord':
      name = "Freljord";
      break;
    case 'bilgewater':
      name = "Bilgewater";
      break;
  }

  return `${name} Cup`;
}

const getTournamentDate = (date: Date): string => {
  return date.toLocaleTimeString();
}

export { dtoToDomain, getTournamentDate, getTournamentName };
