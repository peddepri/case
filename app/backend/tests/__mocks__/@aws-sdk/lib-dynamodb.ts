export const DynamoDBDocumentClient = {
  from: () => ({
    send: async () => ({ Items: [] }),
  }),
};

export class ScanCommand {
  constructor(public input: any) {}
}

export class PutCommand {
  constructor(public input: any) {}
}

export class GetCommand {
  constructor(public input: any) {}
}
