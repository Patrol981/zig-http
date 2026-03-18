const ClashType = {
  Ionia: "ionia",
  Noxus: "noxus",
  Demacia: "demacia",
  Piltover: "piltover",
  Zaun: "zaun",
  Freljord: "freljord",
  Bilgewater: "bilgewater",
  Unknown: "unknown"
};

const ClashInfo = {
  id: 0,
  theme: "",
  day: 0,
  startTime: undefined,
  registrationTime: undefined,
};

/*
info: {
  id,
  nameKey,
  nameKeySecondary,
  schedule: [
    0: {
      cancelled,
      id,
      registrationTime,
      startTime,
    }
  ],
  themeId
}
*/
const getTournamentInfo = (infos) => {
  const clashInfos = [];
  infos.forEach(info => {
    const clashInfo = Object.create(ClashInfo);
    clashInfo.id = info.id;
    clashInfo.theme = info.nameKey;

    const split = info.nameKeySecondary.split("_");
    clashInfo.day = Number.parseInt(split[1]);

    clashInfo.startTime = info.schedule[0].startTime;
    clashInfo.registrationTime = info.schedule[0].registrationTime;

    clashInfos.push(clashInfo);
  });
  return clashInfos;
}

const getTournamentName = (theme) => {
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

const getTournamentDay = (day) => {
  return `Day ${day}`;
}

const getTournamentDate = (date) => {
  const d = new Date(date);
  return d.toGMTString();
}
