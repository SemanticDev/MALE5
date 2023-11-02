//+------------------------------------------------------------------+
//|                                                          svm.mqh |
//|                                    Copyright 2022, Fxalgebra.com |
//|                        https://www.mql5.com/en/users/omegajoctan |
//+------------------------------------------------------------------+
#property copyright "Copyright 2022, Omega Joctan"
#property link      "https://www.mql5.com/en/users/omegajoctan"

#include <MALE5\preprocessing.mqh>
#include <MALE5\matrix_utils.mqh>
#include <MALE5\metrics.mqh>
#include <MALE5\kernels.mqh>

//+------------------------------------------------------------------+
//|  At its core, SVM aims to find a hyperplane that best separates  |
//|  two classes of data points in a high-dimensional space.         |
//|  This hyperplane is chosen to maximize the margin between the    |
//|  two classes, making it the optimal decision boundary.           |
//+------------------------------------------------------------------+

#define RANDOM_STATE 42

class CLinearSVM
  {
   protected:
   
      CMatrixutils      matrix_utils;
      CMetrics          metrics;
      
      CPreprocessing<vector, matrix> *normalize_x;
      
      vector            W;
      double            B; 
      
      bool is_fitted_already;
      
      struct svm_config 
        {
          uint batch_size;
          double alpha;
          double lambda;
          uint epochs;
        };

   private:
      svm_config config;
   
   protected:
        
      
                        double hyperplane(vector &x);
                        
                        int sign(double var);
                        vector sign(const vector &vec);
                        matrix sign(const matrix &mat);
                        
                        void   LangrangeMultipliers();
                        
   public:
                        CLinearSVM(uint batch_size=32, double alpha=0.001, uint epochs= 1000,double lambda=0.1);
                       ~CLinearSVM(void);
                        
                        void fit(matrix &x, vector &y);
                        int predict(vector &x);
                        vector predict(matrix &x);
  };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

CLinearSVM::CLinearSVM(uint batch_size=32, double alpha=0.001, uint epochs= 1000,double lambda=0.1)
 {   
    is_fitted_already = false;
    
    config.batch_size = batch_size;
    config.alpha = alpha;
    config.lambda = lambda;
    config.epochs = epochs;
 }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

CLinearSVM::~CLinearSVM(void)
 {
   delete (normalize_x);
 }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double CLinearSVM::hyperplane(vector &x)
 {
   return x.MatMul(W) - B;   
 }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
/*
void CLinearSVM::LangrangeMultipliers()
 {
   for (ulong i=0; i<m_rows; i++)
      {
      
      }
 }*/
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int CLinearSVM::predict(vector &x)
 { 
   if (!is_fitted_already)
     {
       Print("Err | The model is not trained, call the fit method to train the model before you can use it");
       return 1000;
     }
   
   //Print("hyperplane res = ",hyperplane(x));
     
   return sign(hyperplane(x));
 }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
vector CLinearSVM::predict(matrix &x)
 {
   vector v(x.Rows());
   
   for (ulong i=0; i<x.Rows(); i++)
     v[i] = predict(x.Row(i));
     
   return v;
 }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CLinearSVM::fit(matrix &x, vector &y)
 {
   matrix m_xmatrix = x;
   vector m_yvector = y;
  
   ulong rows = m_xmatrix.Rows(),
         cols = m_xmatrix.Cols();
   
   if (m_xmatrix.Rows() != m_yvector.Size())
      {
         Print("Support vector machine Failed | FATAL | m_xmatrix m_rows not same as yvector size");
         return;
      }
   
   W.Resize(cols);
   B = 0;
   
   //printf("x =[%dx%d] | w = [%dx%d] ",1,m_xmatrix.Cols(),W.Rows(),W.Cols());
    
   normalize_x = new CPreprocessing<vector, matrix>(m_xmatrix, NORM_STANDARDIZATION);
     
//---

  
  if (rows < config.batch_size)
    {
      Print("The number of samples/rows in the dataset should be less than the batch size");
      return;
    }
   
    matrix temp_x;
    vector temp_y;
    matrix w, b;
    
    vector preds = {};
    vector loss(config.epochs);
    

    for (uint epoch=0; epoch<config.epochs; epoch++)
      {
        
         for (uint batch=0; batch<=(uint)MathFloor(rows/config.batch_size); batch+=config.batch_size)
           {
              //printf("batch %d data size %d batch size %d | rows %d",batch,(uint)MathFloor(m_rows/config.batch_size),config.batch_size, m_rows);
              
              //printf("Start %d end %d ",batch, (config.batch_size+batch)-1);
              
              temp_x = matrix_utils.Get(m_xmatrix, batch, (config.batch_size+batch)-1);
              temp_y = matrix_utils.Get(m_yvector, batch, (config.batch_size+batch)-1);
              
              #ifdef DEBUG_MODE:
                  Print("X\n",temp_x,"\ny\n",temp_y);
              #endif 
              
               for (uint sample=0; sample<temp_x.Rows(); sample++)
                  {                                        
                     // yixiw-b≥1
                     
                      if (temp_y[sample] * hyperplane(temp_x.Row(sample))  >= 1) 
                        {
                          this.W -= config.alpha * (2 * config.lambda * this.W); // w = w + α* (2λw - yixi)
                          
                          //Print("drx >= 1");
                        }
                      else
                         {
                           this.W -= config.alpha * (2 * config.lambda * this.W - ( temp_x.Row(sample) * temp_y[sample] )); // w = w + α* (2λw - yixi)
                           
                           this.B -= config.alpha * temp_y[sample]; // b = b - α* (yi)
                           
                           
                           //Print("drx < 1");
                         }  
                  }
           }
        
        //--- Print the loss at the end of an epoch
       
         is_fitted_already = true;  
         
         preds = this.predict(m_xmatrix);
         
         loss[epoch] = metrics.confusion_matrix(m_yvector, preds, false);
        
         printf("---> epoch [%d/%d] Loss = %f ",epoch,config.epochs,loss[epoch]);
         
        #ifdef DEBUG_MODE:  
          Print("W\n",W," B = ",B);  
        #endif   
      }

    return;
 }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int CLinearSVM::sign(double var)
 {
   //Print("Sign input var = ",var);
   
   if (var == 0)
    return (0);
   else if (var < 0)
    return -1;
   else 
    return 1; 
 }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
vector CLinearSVM::sign(const vector &vec)
 {
   vector ret = vec;
   
   for (ulong i=0; i<vec.Size(); i++)
     ret[i] = sign((int)vec[i]);
   
   return ret;
 }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
matrix CLinearSVM::sign(const matrix &mat)
 { 
   matrix ret = mat;
   
   for (ulong i=0; i<mat.Rows(); i++)
     for (ulong j=0; j<mat.Cols(); j++)
        ret[i][j] = sign((int)mat[i][j]); 
        
   return ret;
 }
 
//+------------------------------------------------------------------+
//|                                                                  |
//|                                                                  |
//|             SVM DUAL | for non linear problems                   |
//|                                                                  |
//|                                                                  |
//+------------------------------------------------------------------+

class CDualSVM: protected CLinearSVM
  {
private:
   
   __kernels__       *kernel;
   
   struct dual_svm_config: svm_config //Inherit configs from Linear SVM
    {  
       kernels kernel;
       uint degree;
       double sigma;
       double beta;
    };
   
   dual_svm_config config;
   
   matrix m_xmatrix;
   vector m_yvector;
   
   vector y_labels;
   vector model_alpha;
   
   int decision_function(vector &x);
   double objective(vector &alpha);
      
public:
                     CDualSVM(kernels KERNEL, double alpha, double beta, uint degree, double sigma, uint batch_size=32, uint epochs= 1000);
                    ~CDualSVM(void);
                    
                    void fit(matrix &x, vector &y);
                    vector predict(matrix &x);
                    int predict(vector &x);

  };
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CDualSVM::CDualSVM(kernels KERNEL,
                   double alpha, 
                   double beta, 
                   uint  degree, 
                   double sigma,
                   uint batch_size=32, 
                   uint epochs= 1000
                   )
 {
    kernel = new __kernels__(KERNEL, alpha, beta, degree, sigma);
   
    config.kernel = KERNEL;
    config.alpha = alpha; 
    config.beta = beta;
    config.degree = degree; 
    config.sigma = sigma;
    config.batch_size = batch_size;
    config.epochs = epochs;
    
 }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CDualSVM::~CDualSVM(void)
 {
   delete (kernel);
   delete (normalize_x);
 }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int CDualSVM::decision_function(vector &x)
 { 
   matrix labels_matrix; y_labels.Swap(labels_matrix);
   matrix alpha;   model_alpha.Swap(alpha);
   matrix x_mat; x.Swap(x_mat);
   
   
   double kernel_res = this.kernel.KernelFunction(m_xmatrix, x_mat);
   
   Print("decision function = ",model_alpha.MatMul(y_labels * kernel_res));
   
   //Print("decision function =",(alpha * labels_matrix).MatMul(kernel_res));

   return 0;
 }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

int CDualSVM::predict(vector &x)
 { 
   if (!is_fitted_already)
     {
       Print("Err | The model is not trained, call the fit method to train the model before you can use it");
       return 1000;
     }
   
   if (x.Size() <=0)
     {
       Print(__FUNCTION__," Err invalid x size ");
       return 1e3;
     }
     
   //Print("decision_function res = ",decision_function(x));
   
   Print("Pred x = ",x);
     
   return sign(decision_function(x));
 }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
vector CDualSVM::predict(matrix &x)
 {
   vector v(x.Rows());
   
   for (ulong i=0; i<x.Rows(); i++)
     v[i] = predict(x.Row(i));
     
   return v;
 }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double CDualSVM::objective(vector &alpha)
 { 
   return -1 * alpha.Sum() * 0.5 * (alpha.Outer(alpha) * m_yvector.Outer(m_yvector) * this.kernel.KernelFunction(m_xmatrix,m_xmatrix)).Sum();
 }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CDualSVM::fit(matrix &x,vector &y)
 {
   m_xmatrix = x;
   m_yvector = y;
   

   y_labels = this.matrix_utils.Classes(m_yvector);
   
   
   ulong rows = m_xmatrix.Rows(), 
         cols = m_xmatrix.Cols();
         
   model_alpha = matrix_utils.Zeros(rows);
   
   
   if (m_xmatrix.Rows() != m_yvector.Size())
      {
         Print("Support vector machine Failed | FATAL | m_xmatrix m_rows not same as yvector size");
         return;
      }
   
   W.Resize(cols);
   B = 0;
   
   //printf("x =[%dx%d] | w = [%dx%d] ",1,m_xmatrix.Cols(),W.Rows(),W.Cols());
    
   //normalize_x = new CPreprocessing<vector, matrix>(m_xmatrix, NORM_STANDARDIZATION);
     
//---

  
  if (rows < config.batch_size)
    {
      Print("The number of samples/rows in the dataset should be less than the batch size");
      return;
    }
   
    matrix temp_x;
    vector temp_y;
    matrix w, b;
    
    vector preds = {};
    vector loss(config.epochs);
    vector ones(rows);
    ones.Fill(1); 
    
    for (uint epoch=0; epoch<config.epochs; epoch++)
      {
      
       //Print("objective = ",objective(model_alpha));
       
       vector gradient = ones - (model_alpha.Outer(model_alpha) * m_yvector.Outer(m_yvector) * this.kernel.KernelFunction(m_xmatrix,m_xmatrix)).Sum();
       //Print("Gradients =",gradient,"\nkernel\n",this.kernel.KernelFunction(m_xmatrix,m_xmatrix),"\nalphas.outer\n",model_alpha.Outer(model_alpha),"\nouter.y\n",m_yvector.Outer(m_yvector));
       
       model_alpha += config.alpha * gradient;
       model_alpha.Clip(0, INT_MAX);
       
        /*
         for (uint batch=0; batch<=(uint)MathFloor(rows/config.batch_size); batch+=config.batch_size)
           {
              //printf("batch %d data size %d batch size %d | rows %d",batch,(uint)MathFloor(m_rows/config.batch_size),config.batch_size, m_rows);
              
              //printf("Start %d end %d ",batch, (config.batch_size+batch)-1);
              
              temp_x = matrix_utils.Get(m_xmatrix, batch, (config.batch_size+batch)-1);
              temp_y = matrix_utils.Get(m_yvector, batch, (config.batch_size+batch)-1);
              
              #ifdef DEBUG_MODE:
                  Print("X\n",temp_x,"\ny\n",temp_y);
              #endif 
              
               for (uint sample=0; sample<temp_x.Rows(); sample++)
                  {                                        
                     // yixiw-b≥1
                     
                      if (temp_y[sample] * decision_function(temp_x.Row(sample))  >= 1) 
                        {
                          this.W -= config.alpha * (2 * config.lambda * this.W); // w = w + α* (2λw - yixi)
                          
                          //Print("drx >= 1");
                        }
                      else
                         {
                           this.W -= config.alpha * (2 * config.lambda * this.W - ( temp_x.Row(sample) * temp_y[sample] )); // w = w + α* (2λw - yixi)
                           
                           this.B -= config.alpha * temp_y[sample]; // b = b - α* (yi)
                           
                           
                           //Print("drx < 1");
                         }  
                  }
           }
           
        //--- Print the loss at the end of an epoch
       */
         is_fitted_already = true;  
       /*  
         preds = this.predict(m_xmatrix);
         
         loss[epoch] = metrics.confusion_matrix(m_yvector, preds, false);
        
         printf("---> epoch [%d/%d] Loss = %f ",epoch,config.epochs,loss[epoch]);
         
        #ifdef DEBUG_MODE:  
          Print("W\n",W," B = ",B);  
        #endif   
        
         */
      }
    
   Print("Optimal Lagrange Multipliers (alpha):", model_alpha);
      
    return;
 }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
