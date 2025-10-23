import { GenericContainer, StartedTestContainer, Wait } from 'testcontainers'
import app from '../src/index'
import request from 'supertest'

let container: StartedTestContainer
let baseUrl: string

jest.setTimeout(120000)

beforeAll(async () => {
  container = await new GenericContainer('wiremock/wiremock:3.8.0')
    .withExposedPorts(8080)
    .withWaitStrategy(Wait.forLogMessage('verbose: Notifier started'))
    .start()
  const host = container.getHost()
  const port = container.getMappedPort(8080)
  baseUrl = `http://${host}:${port}`

  // Create stub
  const stub = {
    request: { method: 'GET', urlPathPattern: '/price/.*' },
    response: { status: 200, headers: { 'Content-Type': 'application/json' }, jsonBody: { price: 42.5 } }
  }
  await fetch(`${baseUrl}/__admin/mappings`, { method: 'POST', body: JSON.stringify(stub), headers: { 'Content-Type': 'application/json' } })

  process.env.PRICE_SERVICE_URL = baseUrl
})

afterAll(async () => {
  if (container) await container.stop()
})

describe('Orders price external dependency', () => {
  it('returns mocked price', async () => {
    const resp = await request(app).get('/api/orders/price/book').expect(200)
    expect(resp.body).toHaveProperty('price', 42.5)
  })
})
