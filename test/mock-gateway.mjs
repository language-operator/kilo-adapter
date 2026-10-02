// A stand-in for the cluster's OpenAI-compatible model gateway, just enough of
// the Responses API (which Kilo's `openai` provider speaks) for one task-mode
// run. Every request is logged as one JSON line, so the test can assert on what
// Kilo actually sent: the model, the bearer key, and the prompt.
//
// The known model gets a streamed one-line answer. Any other model gets the 400
// a LiteLLM gateway returns for a model it does not route.
import http from 'node:http';

const MODEL = process.env.MOCK_MODEL ?? 'kilo-test-model';
const port = Number(process.env.PORT ?? 18080);

http.createServer((req, res) => {
  let body = '';
  req.on('data', (chunk) => { body += chunk; });
  req.on('end', () => {
    let json = {};
    try { json = JSON.parse(body); } catch { /* not JSON */ }
    console.log(JSON.stringify({ method: req.method, url: req.url, model: json.model ?? null, auth: req.headers.authorization ?? null, body }));

    if (req.method !== 'POST' || !req.url.endsWith('/responses')) {
      res.writeHead(404, { 'content-type': 'application/json' });
      return res.end(JSON.stringify({ error: { message: `no route for ${req.method} ${req.url}` } }));
    }
    if (json.model !== MODEL) {
      res.writeHead(400, { 'content-type': 'application/json' });
      return res.end(JSON.stringify({ error: { message: `Invalid model name passed in model=${json.model}`, type: 'invalid_request_error', code: '400' } }));
    }

    res.writeHead(200, { 'content-type': 'text/event-stream' });
    const send = (type, fields) => res.write(`event: ${type}\ndata: ${JSON.stringify({ type, ...fields })}\n\n`);
    const response = { id: 'resp_1', object: 'response', created_at: 1, model: MODEL, status: 'in_progress', output: [] };
    const item = { id: 'msg_1', type: 'message', role: 'assistant', status: 'in_progress', content: [] };
    const text = 'TASK-DONE';
    const done = { ...item, status: 'completed', content: [{ type: 'output_text', text, annotations: [] }] };
    send('response.created', { response });
    send('response.output_item.added', { output_index: 0, item });
    send('response.content_part.added', { item_id: item.id, output_index: 0, content_index: 0, part: { type: 'output_text', text: '', annotations: [] } });
    send('response.output_text.delta', { item_id: item.id, output_index: 0, content_index: 0, delta: text });
    send('response.output_text.done', { item_id: item.id, output_index: 0, content_index: 0, text });
    send('response.output_item.done', { output_index: 0, item: done });
    send('response.completed', { response: { ...response, status: 'completed', output: [done], usage: { input_tokens: 1, output_tokens: 1, total_tokens: 2 } } });
    res.end();
  });
}).listen(port, () => console.error(`mock gateway on :${port}`));
