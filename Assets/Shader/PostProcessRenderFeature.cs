using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.Scripting.APIUpdating;


public class PostProcessRenderFeature : ScriptableRendererFeature
{
    //这个是用于后处理的RenderFeature

    [System.Serializable]
    public class Setting
    {
        public RenderPassEvent passEvent = RenderPassEvent.BeforeRenderingOpaques;//设置渲染顺序
        public Material material;//用于后处理的材质
        public int PassIndex = 0;
    }

    public Setting setting = new Setting();

    [System.Serializable]

    public class CustomRenderPass : ScriptableRenderPass
    {
        public Setting setting;//实例化设置
        private RenderTargetIdentifier passSource { get; set; }

        RenderTargetHandle passTemplecolorTex;//临时计算图像，用于后处理
        public FilterMode passfiltermode { get; set; }//图像的模式
        public CustomRenderPass(Setting setting)
        {
            this.setting = setting;
        }

        public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)//初始化
        {

        }


        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)//渲染在此进行
        {
            //后处理需要用CommandBuffer来传递Buffer
            CommandBuffer cmd = CommandBufferPool.Get("passTag"); //得到pass名字

            RenderTextureDescriptor opaquedesc = renderingData.cameraData.cameraTargetDescriptor;//得到屏幕图像数据，（用于根据屏幕图形长宽来设定临时图像的长宽）

            passSource = renderingData.cameraData.renderer.cameraColorTarget;//得到屏幕图像

            cmd.GetTemporaryRT(passTemplecolorTex.id, opaquedesc, passfiltermode);//申请一个临时图像

            Blit(cmd, passSource, passTemplecolorTex.Identifier(), setting.material, setting.PassIndex);//把源贴图输入到材质对应的pass里处理，并把处理结果的图像存储到临时图像；

            Blit(cmd, passTemplecolorTex.Identifier(), passSource);//然后把临时图像又存到源图像里 

            context.ExecuteCommandBuffer(cmd);//执行命令缓冲区的该命令

            cmd.Clear();

            CommandBufferPool.Release(cmd);//释放该命令

            cmd.ReleaseTemporaryRT(passTemplecolorTex.id);//释放临时图像
        }


        public override void FrameCleanup(CommandBuffer cmd)//清除在执行此渲染过程期间创建的所有已分配资源                                                          
        {

        }
    }

    CustomRenderPass m_ScriptablePass;

    public override void Create()//创建自定义RednerPass
    {
        m_ScriptablePass = new CustomRenderPass(setting);
        m_ScriptablePass.renderPassEvent = setting.passEvent;
    }
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        renderer.EnqueuePass(m_ScriptablePass);//添加Pass
    }
}


