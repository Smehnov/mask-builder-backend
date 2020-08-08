#include "Scripts/src/Plugins.as"

class RandomTestPlugin : BasePlugin
{
    //  Read / reread from Configuration JSON
    String trigger = "tap+recording";
    String question_tag = "question";
    String question_texture = "";
    String answer_tag = "answer";
    String answer_texture = "";
    bool slow_down_mode = true;
    float answer_time = 5.0;

    //  Read from assets
    Array<String> answerTextureFileNames;
    Material@ materialPatch;
    Material@ materialQuestionPatch;

    //  Run-time variables
    int counter = 0;
    int randomOffset = 0;
    int framesCount = 0;
    float elapsedTime = 0.0;

    float answer_delay = 0.1;

    // Flags
    bool onQuestion = true;
    bool onAnswer = false;
    bool onWait = false;

    void init() override
    {
        SetRandomSeed(time.systemTime);
        
        LoadSettings();

        //  Setup quiestion node and texture
        Node@ questionNode = scene.GetChildrenWithTag(question_tag, true)[0];
        BillboardSet@ bbsQuestionPatch = questionNode.GetComponent("BillboardSet");
        materialQuestionPatch = bbsQuestionPatch.material;
        if (question_texture != "")
        {
            Texture2D@ tex = cache.GetResource("Texture2D", question_texture);
            if (tex !is null)
                materialQuestionPatch.textures[TU_DIFFUSE] = tex;
            else
                log.Error("Failed to load texture file '" + question_texture + "'");
        };

        //  Setup answer node and first texture
        Node@ patchNode = scene.GetChildrenWithTag(answer_tag, true)[0];
        BillboardSet@ bbsPatch = patchNode.GetComponent("BillboardSet");
        materialPatch = bbsPatch.material;
        if (answer_texture != "")
        {
            Texture2D@ tex = cache.GetResource("Texture2D", answer_texture);
            if (tex !is null)
                answerTextureFileNames.Push(answer_texture);
            else
                log.Error("Failed to load texture file '" + answer_texture + "'");
        }

        // Read paths to all other textures
        String path = GetPath(answer_texture);
        String file = GetFileName(answer_texture);
        String extension = GetExtension(answer_texture, false);
        for (int a = 1; ; ++a)
        {
            String fileName = path + file + String(a) + extension;

            if (cache.Exists(fileName))
            {
                Texture2D@ tex = cache.GetResource("Texture2D", fileName);
                if (tex !is null)
                {
                    answerTextureFileNames.Push(fileName);
                    ++framesCount;
                }
                else
                    log.Error("Failed to load texture file '" + fileName + "'");
            }
            else
                break;
        };

        // Subscriptions
        SubscribeToEvent("Update", "HandleUpdate");
        if (trigger == "mouth")
            SubscribeToEvent("MouthTrigger", "HandleMouthTrigger");
        else
            SubscribeToEvent("MouseEvent", "HandleMouseEvent");
    };

    void LoadSettings() 
    {
        JSONFile settingsParameters;
        settingsParameters.Load(cache.GetFile("Scripts/PluginConfiguration.json"));  
        JSONValue jsonSettigns = settingsParameters.GetRoot();   

        if (jsonSettigns.Contains("RandomTest")) 
        {
            JSONValue pluginRoot = jsonSettigns.Get("RandomTest");

            if (pluginRoot.Contains("trigger"))
                trigger = pluginRoot.Get("trigger").GetString();

            if (pluginRoot.Contains("question"))
            {
                JSONValue pluginRoot_question = pluginRoot.Get("question");

                if (pluginRoot_question.Contains("tag"))
                    question_tag = pluginRoot_question.Get("tag").GetString();

                if (pluginRoot_question.Contains("texture"))
                    question_texture = pluginRoot_question.Get("texture").GetString();
            };

            if (pluginRoot.Contains("answer"))
            {
                JSONValue pluginRoot_answer = pluginRoot.Get("answer");

                if (pluginRoot_answer.Contains("tag"))
                    answer_tag = pluginRoot_answer.Get("tag").GetString();

                if (pluginRoot_answer.Contains("texture"))
                    answer_texture = pluginRoot_answer.Get("texture").GetString();

                if (pluginRoot_answer.Contains("slow_down"))
                    slow_down_mode = pluginRoot_answer.Get("slow_down").GetBool();

                if (pluginRoot_answer.Contains("time"))
                    answer_time = pluginRoot_answer.Get("time").GetFloat();
            };

        };
    };

    void setFrame(int index) 
    {
        Texture2D@ tex = cache.GetResource("Texture2D", answerTextureFileNames[index]);
        if (tex !is null)
            materialPatch.textures[TU_DIFFUSE] = tex;
    };

    void setRandom() 
    {
        randomOffset = RandomInt(framesCount);
    };

    void start()
    {
        setRandom();
        elapsedTime = 0.0;

        onQuestion = false;
        onAnswer = true;
        onWait = false;
    };

    void wait()
    {
        onQuestion = false;
        onAnswer = false;
        onWait = true;
    };

    void stop()
    {
        onQuestion = true;
        onAnswer = false;
        onWait = false;
    };

    void HandleUpdate(StringHash eventType, VariantMap& eventData)
    {
        if (!onQuestion)
        {
            elapsedTime += eventData["TimeStep"].GetFloat();

            if (onAnswer)
            {
                if (slow_down_mode)
                {
                    // increment every 'answer_time / 10' seconds as a function of arctangent
                    float factor = answer_time / 10;
                    counter = uint(Atan(elapsedTime / factor) * factor * 2);
                }
                else
                    // increment every 'answer_delay' seconds
                    counter = uint(elapsedTime / answer_delay);
                
                uint currentFrame = uint((counter + randomOffset) % framesCount);

                if (elapsedTime < answer_time)
                    setFrame(currentFrame);
                else
                    wait();
            };
            
            materialPatch.shaderParameters["MatDiffColor"]  = Variant(Vector4(1.0f, 1.0f, 1.0f, 1.0f));
            materialQuestionPatch.shaderParameters["MatDiffColor"]  = Variant(Vector4(1.0f, 1.0f, 1.0f, 0.0f));
        } else {
            materialPatch.shaderParameters["MatDiffColor"]  = Variant(Vector4(1.0f, 1.0f, 1.0f, 0.0f));
            materialQuestionPatch.shaderParameters["MatDiffColor"]  = Variant(Vector4(1.0f, 1.0f, 1.0f, 1.0f));
        };
    };

    void checkState(bool rec)
    {
        if (onQuestion) {
            start();
        };

        if (onAnswer) {

        };

        if (onWait && !rec) {
            stop();
        };
    };

    void HandleMouthTrigger(StringHash eventType, VariantMap& eventData)
    {
        if (eventData["Opened"].GetBool())
            checkState(false);
    };

    void HandleMouseEvent(StringHash eventType, VariantMap& eventData)
    {
        if (eventData["Event"].GetString() == "tap")
            checkState(false);
            
        if (eventData["Event"].GetString() == "doubletap" && trigger == "tap+recording")
            checkState(true);
    };
};

class RandomTestPluginToFactory
{
    RandomTestPluginToFactory()
    {
        g_PluginsFactory.addPlugin(RandomTestPlugin());  
    };
};

RandomTestPluginToFactory g_RandomTestPluginToFactory;