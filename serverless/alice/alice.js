const {TranslationService, TranslateRequest} = require('yandex-cloud/api/ai/translate/v2');

const translationService = new TranslationService();

function sendResponse(event, text, endSession) {
    const {version, session, request} = event;
    return {
        version,
        session,
        response: {
            text: text,
            end_session: endSession === true,
        },
    }
}

async function translate(text) {
    let response = await translationService.translate({
        targetLanguageCode: 'en',
        format: TranslateRequest.Format.PLAIN_TEXT,
        texts: [text],
    });
    return response.translations[0].text;
}

async function handler(event) {
    let query = event.request['original_utterance'];
    if (!query || query.length === 0) {
        return sendResponse(event, 'Привет! Я переведу на анлийский всё, что вы мне cкажете.');
    }
    query = query.replace(/^переведи\s?/, '');

    const translated = await translate(query);
    return sendResponse(
        event,
        `${query} по-английски будет ${translated}. Обращайтесь ещё!`,
        true,
    );
}

module.exports = {
    handler,
};
