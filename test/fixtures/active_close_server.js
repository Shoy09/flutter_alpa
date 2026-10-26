'use strict';
// Test-only in-memory persistence. Never loads credentials or real Sequelize models.
const http = require('node:http');
const path = require('node:path');
const root = process.env.SYNC_BACKEND_ROOT;
const { createOperation, updateOperation } = require(path.join(root, 'src/services/operationSyncIdentity'));
const { confirmClosedTransfer, resolveClosedTransfer, lookupSync } = require(path.join(root, 'src/services/closedTransfer'));
const records = new Map();
let sequence = 0, tail = Promise.resolve();
const Model = {
  rawAttributes: new Proxy({}, { get() { return {}; } }),
  sequelize: { transaction(action) {
    const task = tail.then(() => action({ LOCK: { UPDATE: 'UPDATE' } }));
    tail = task.catch(() => {}); return task;
  } },
  async findOrCreate({ where, defaults }) {
    if (records.has(where.sync_uuid)) return [records.get(where.sync_uuid), false];
    const row = { ...defaults, id: ++sequence,
      toJSON() { const { toJSON, update, ...data } = this; return data; },
      async update(values) { Object.assign(this, values); return this; },
    };
    records.set(where.sync_uuid, row); return [row, true];
  },
  async findByPk(id) { return [...records.values()].find(row => row.id === Number(id)) || null; },
  async findOne({ where }) { return records.get(where.sync_uuid) || null; },
};
const server = http.createServer(async (req, res) => {
  try {
    let text = ''; for await (const chunk of req) text += chunk;
    const body = text ? JSON.parse(text) : {};
    let data;
    if (req.url.endsWith('/crear')) {
      data = await Promise.all(body.data.map(item => createOperation(Model, item, body.tipo)));
    } else if (req.url.endsWith('/update-masivo')) {
      data = [];
      for (const item of body.data) {
        try {
          const result = await updateOperation(Model, body.tipo, item.idNube, item);
          data.push({ idNube: item.idNube, actualizado: true, cloud_hash: result.cloud_hash });
        } catch (error) { data.push({ idNube: item.idNube, actualizado: false, error: error.message }); }
      }
    } else if (req.url.endsWith('/confirm-closed-transfer')) {
      data = body.review ? await resolveClosedTransfer(Model, body.tipo, body.payload, body.hash, body.review)
        : await confirmClosedTransfer(Model, body.tipo, body.payload, body.hash);
    } else if (req.url.endsWith('/lookup-sync')) {
      data = await lookupSync(Model, body.tipo, body.payload, body.hash);
    } else if (req.url === '/inspect') {
      data = [...records.values()].map(record => record.toJSON());
    } else throw new Error('Unexpected route: ' + req.url);
    res.setHeader('Content-Type', 'application/json'); res.end(JSON.stringify({ ok: true, data }));
  } catch (error) { res.statusCode = 400; res.end(JSON.stringify({ ok: false, error: error.message })); }
});
server.listen(0, '127.0.0.1', () => process.stdout.write(String(server.address().port) + '\n'));
