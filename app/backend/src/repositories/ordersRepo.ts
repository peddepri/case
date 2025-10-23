import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { DynamoDBDocumentClient, ScanCommand, PutCommand } from "@aws-sdk/lib-dynamodb";

export interface Order { id: string; item: string; price: number; createdAt: string }

const tableName = process.env.DDB_TABLE || process.env.DYNAMODB_TABLE || "orders";
const region = process.env.AWS_REGION || process.env.AWS_DEFAULT_REGION || "us-east-1";
const endpoint = process.env.DYNAMODB_ENDPOINT; // e.g., http://dynamodb-local:8000 for local dev

const ddb = new DynamoDBClient({ region, ...(endpoint ? { endpoint } : {}) });
const doc = DynamoDBDocumentClient.from(ddb, { marshallOptions: { removeUndefinedValues: true } });

export async function listOrders(): Promise<Order[]> {
  const out = await doc.send(new ScanCommand({ TableName: tableName, Limit: 200 }));
  return (out.Items || []) as Order[];
}

export async function createOrder(order: Omit<Order, "createdAt">): Promise<Order> {
  const item: Order = { ...order, createdAt: new Date().toISOString() };
  await doc.send(new PutCommand({ TableName: tableName, Item: item }));
  return item;
}
